defmodule DBML do
  def parse(doc) do
    case DBML.Parser.parse(doc) do
      {:ok, entries, "", _, _, _} ->
        {project, entries} = pop_project(entries)

      _other ->
        :error
    end
  end

  defp pop_project(entries) do
    case pop_values(entries, :project) do
      {[], _entries} ->
        nil

      {[project], _enries} ->
        DBML.Project.new(project)

      {projects, _} ->
        raise "expects only one project, got " <> inspect(projects)
    end
  end

  defp pop_values(keyword, key) do
    case Keyword.get_values(keyword, key) do
      [] -> {[], keyword}
      values -> {values, Keyword.delete(keyword, key)}
    end
  end
end
