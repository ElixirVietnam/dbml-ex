defmodule DBML.MixProject do
  use Mix.Project

  def project() do
    [
      app: :dbml,
      version: "0.1.0",
      elixir: "~> 1.10",
      deps: deps()
    ]
  end

  def application(), do: []

  defp deps() do
    [
      {:nimble_parsec, "~> 0.6"}
    ]
  end
end
