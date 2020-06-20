defmodule DBML do
  def parse(doc) do
    case DBML.Parser.parse(doc) do
      {:ok, tokens, "", _, _, _} ->
        {:ok, tokens}

      other ->
        IO.inspect other
        :error
    end
  end
end
