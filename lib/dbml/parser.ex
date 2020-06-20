defmodule DBML.Parser do
  import NimbleParsec

  @space_characters [?\s]
  @newline_characters [?\n]
  @whitespace_characters @space_characters ++ @newline_characters

  # Misc.
  required_spaces = ignore(ascii_string(@space_characters, min: 1))
  optional_spaces = ignore(ascii_string(@space_characters, min: 0))

  required_whitespaces = ignore(ascii_string(@whitespace_characters, min: 1))
  optional_whitespaces = ignore(ascii_string(@whitespace_characters, min: 0))

  comment =
    lookahead(string("//"))
    |> ignore(string("//"))
    |> ascii_string([not: ?\n], min: 1)

  misc = ignore(choice([comment, required_whitespaces]))

  single_quoted_string =
    ignore(string("'"))
    |> utf8_string([not: ?'], min: 1)
    |> ignore(string("'"))

  double_quoted_string =
    ignore(string("\""))
    |> utf8_string([not: ?"], min: 1)
    |> ignore(string("\""))

  multiline_string =
    ignore(string("'''"))
    |> repeat(
      lookahead_not(string("'''"))
      |> utf8_char([])
    )
    |> ignore(string("'''"))
    |> reduce({IO, :iodata_to_binary, []})

  quoted_string = choice([double_quoted_string, single_quoted_string, multiline_string])

  number =
    optional(string("-"))
    |> integer(min: 1)
    |> optional(
      ignore(string("."))
      |> ascii_string([?0..?9], min: 1)
    )
    |> reduce({DBML.Utils, :to_number, []})

  boolean = choice([replace(string("true"), true), replace(string("false"), false)])
  null = replace(string("null"), nil)

  expression =
    lookahead(string("`"))
    |> ignore(string("`"))
    |> ascii_string([not: ?`], min: 1)
    |> ignore(string("`"))
    |> unwrap_and_tag(:expression)

  identifier =
    choice([
      double_quoted_string,
      ascii_string([?0..?9, ?A..?Z, ?a..?z, ?_], min: 1)
    ])

  note_definition =
    lookahead(string("note"))
    |> ignore(string("note"))
    |> repeat(misc)
    |> choice([
      lookahead(string("{"))
      |> ignore(string("{"))
      |> repeat(misc)
      |> concat(quoted_string)
      |> repeat(misc)
      |> ignore(string("}")),
      ignore(string(":")) |> repeat(misc) |> concat(quoted_string)
    ])

  project_definitions =
    ignore(string("{"))
    |> repeat(
      choice([
        misc,
        note_definition |> unwrap_and_tag(:note),
        unwrap_and_tag(identifier, :key)
        |> ignore(string(":"))
        |> ignore(misc)
        |> unwrap_and_tag(quoted_string, :value)
        |> tag(:meta)
      ])
    )
    |> ignore(string("}"))

  project =
    lookahead(string("project"))
    |> ignore(string("project"))
    |> ignore(required_spaces)
    |> unwrap_and_tag(identifier, :name)
    |> repeat(misc)
    |> tag(project_definitions, :definitions)

  # Tables.

  column_type =
    choice([
      double_quoted_string,
      ascii_string([not: ?\s, not: ?\n, not: ?{, not: ?}], min: 1)
    ])

  ref_column =
    unwrap_and_tag(identifier, :table)
    |> ignore(string("."))
    |> unwrap_and_tag(identifier, :column)
    |> wrap()

  default_choices = choice([quoted_string, number, boolean, expression, null])

  ref_type =
    choice([
      string(">") |> replace(:many_to_one),
      string("<") |> replace(:one_to_many),
      string("-") |> replace(:one_to_one)
    ])

  column_ref =
    lookahead(string("ref:"))
    |> ignore(string("ref:"))
    |> concat(optional_whitespaces)
    |> unwrap_and_tag(ref_type, :type)
    |> concat(optional_spaces)
    |> unwrap_and_tag(ref_column, :related)

  column_setting =
    choice([
      ignore(string("default:")) |> repeat(misc) |> concat(default_choices) |> unwrap_and_tag(:default),
      choice([string("pk"), string("primary")]) |> replace(true) |> unwrap_and_tag(:primary),
      ignore(string("increment")) |> replace(true) |> unwrap_and_tag(:autoincrement),
      ignore(string("unique")) |> replace(true) |> unwrap_and_tag(:unique),
      ignore(string("null")) |> replace(true) |> unwrap_and_tag(:null),
      ignore(string("not null")) |> replace(false) |> unwrap_and_tag(:null),
      ignore(string("note:")) |> repeat(misc) |> concat(quoted_string) |> unwrap_and_tag(:note),
      tag(column_ref, :reference)
    ])

  column_settings =
    ignore(string("["))
    |> repeat(misc)
    |> concat(column_setting)
    |> repeat(
      choice([
        misc,
        ignore(string(","))
        |> repeat(misc)
        |> concat(column_setting)
      ])
    )
    |> ignore(string("]"))
    |> wrap()

  column_definition =
    unwrap_and_tag(identifier, :name)
    |> ignore(required_spaces)
    |> unwrap_and_tag(column_type, :type)
    |> optional(
      ignore(required_spaces)
      |> unwrap_and_tag(column_settings, :settings)
    )

  index_settings =
    lookahead(string("["))
    |> ignore(string("["))
    |> repeat(
      choice([
        misc,
        string("pk") |> replace(true) |> unwrap_and_tag(:primary),
        string("unique") |> replace(true) |> unwrap_and_tag(:unique),
        ignore(string("type:")) |> repeat(misc) |> choice([string("hash"), string("btree")]) |> unwrap_and_tag(:type),
        ignore(string("name:")) |> repeat(misc) |> concat(identifier) |> unwrap_and_tag(:name)
      ])
    )
    |> ignore(string("]"))

  single_column_index =
    tag(identifier, :columns)
    |> ignore(required_spaces)
    |> tag(optional(index_settings), :options)
    |> wrap()

  composite_index =
    lookahead(string("("))
    |> ignore(string("("))
    |> ignore(optional_spaces)
    |> choice([expression, identifier])
    |> repeat(
      choice([
        misc,
        lookahead(string(","))
        |> ignore(string(","))
        |> repeat(misc)
        |> choice([expression, identifier])
      ])
    )
    |> ignore(string(")"))
    |> tag(:columns)
    |> ignore(optional_spaces)
    |> tag(optional(index_settings), :options)
    |> wrap()

  index_definition = choice([composite_index, single_column_index])

  indexes =
    lookahead(string("indexes"))
    |> ignore(string("indexes"))
    |> repeat(misc)
    |> ignore(string("{"))
    |> repeat(
      choice([misc, index_definition])
    )
    |> ignore(string("}"))
    |> wrap()

  table_definitions =
    ignore(string("{"))
    |> repeat(
      choice([
        misc,
        tag(column_definition, :column)
      ])
    )
    |> repeat(
      choice([
        misc,
        unwrap_and_tag(note_definition, :note),
        unwrap_and_tag(indexes, :indexes)
      ])
    )
    |> ignore(string("}"))

  table =
    lookahead(string("table"))
    |> ignore(string("table"))
    |> ignore(required_spaces)
    |> unwrap_and_tag(identifier, :name)
    |> optional(
      required_spaces
      |> ignore(string("as"))
      |> concat(required_spaces)
      |> concat(identifier)
      |> unwrap_and_tag(:alias)
    )
    |> repeat(misc)
    |> tag(table_definitions, :definitions)

  # Table groups.
  table_group =
    lookahead(string("tablegroup"))
    |> ignore(string("tablegroup"))
    |> repeat(misc)
    |> ignore(string("{"))
    |> repeat(choice([misc, identifier]))
    |> ignore(string("}"))

  # Enum
  enum_definition =
    unwrap_and_tag(identifier, :value)
    |> repeat(misc)
    |> optional(
      lookahead(string("["))
      |> ignore(string("["))
      |> repeat(misc)
      |> ignore(string("note:"))
      |> repeat(misc)
      |> unwrap_and_tag(quoted_string, :note)
      |> repeat(misc)
      |> ignore(string("]"))
    )
    |> wrap()

  enum =
    lookahead(string("enum"))
    |> ignore(string("enum"))
    |> ignore(required_spaces)
    |> unwrap_and_tag(identifier, :name)
    |> repeat(misc)
    |> ignore(string("{"))
    |> tag(repeat(choice([misc, enum_definition])), :values)
    |> ignore(string("}"))

  # References
  ref_short_form =
    lookahead(string(":"))
    |> ignore(string(":"))
    |> repeat(misc)
    |> unwrap_and_tag(ref_column, :owner)
    |> repeat(misc)
    |> unwrap_and_tag(ref_type, :type)
    |> concat(optional_spaces)
    |> unwrap_and_tag(ref_column, :related)

  ref_long_form =
    repeat(misc)
    |> ignore(string("{"))
    |> repeat(misc)
    |> unwrap_and_tag(ref_column, :owner)
    |> repeat(misc)
    |> unwrap_and_tag(ref_type, :type)
    |> concat(optional_spaces)
    |> unwrap_and_tag(ref_column, :related)
    |> repeat(misc)
    |> ignore(string("}"))

  ref =
    lookahead(string("ref"))
    |> ignore(string("ref"))
    |> optional(
      ignore(required_spaces)
      |> tag(identifier, :name)
    )
    |> choice([ref_short_form, ref_long_form])

  parser =
    repeat(
      choice([
        misc,
        tag(project, :project),
        tag(table, :table),
        tag(table_group, :table_group),
        tag(enum, :enum),
        tag(ref, :ref)
      ])
    )
    |> repeat(misc)

  # defparsec(:project, project)
  # defparsec(:table, table)
  # defparsec(:table_group, table_group)
  # defparsec(:enum, enum)
  # defparsec(:ref, ref)
  defparsec(:parse, parser)
end
