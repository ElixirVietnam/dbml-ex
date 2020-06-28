defmodule DBML.Project do
  defstruct [:name]

  def new(data) do
    name = Keyword.get(data, :name)

    %__MODULE__{name: name}
  end
end
