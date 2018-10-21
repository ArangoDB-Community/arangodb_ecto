defmodule ArangodbEcto.Mixfile do
  use Mix.Project

  @version "0.1.0"
  @url "https://github.com/lean5/arangodb_ecto"

  def project do
    [
      app: :arangodb_ecto,
      name: "ArangoDB.Ecto",
      version: @version,
      elixir: "~> 1.4",
      package: package(),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      description: description(),
      docs: docs(),
      deps: deps()
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:ecto, "~> 2.2"},
      {:arangoex, github: "mpoeter/arangoex"},
      {:dialyxir, "~> 0.5", only: :dev, runtime: false},
      {:ex_doc, "~> 0.16", only: :dev, runtime: false}
    ]
  end

  defp description do
    """
    ArangoDB adapter for Ecto
    """
  end

  defp package do
    [
      maintainers: ["Manuel Pöter"],
      licenses: ["MIT"],
      links: %{"GitHub" => @url},
      files: ["lib", "mix.exs", "README.md"]
    ]
  end

  defp docs do
    [extras: ["README.md"], main: "readme", source_ref: "v#{@version}", source_url: @url]
  end
end
