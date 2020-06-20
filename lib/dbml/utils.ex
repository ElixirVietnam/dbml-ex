defmodule DBML.Utils do
  def to_number([whole]) when is_integer(whole), do: whole
  def to_number(["-", whole]) when is_integer(whole), do: -whole

  def to_number([whole, decimal]) when is_integer(whole) do
    String.to_float(Integer.to_string(whole) <> "." <> decimal)
  end

  def to_number(["-", whole, decimal]) do
    -to_number([whole, decimal])
  end
end
