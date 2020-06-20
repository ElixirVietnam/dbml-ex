defmodule DBML.Project do
  defstruct [:database_type, :note]

  def new(keyword) do
    struct(__MODULE__, keyword)
  end
end
