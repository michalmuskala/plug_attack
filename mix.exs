defmodule PlugAttack.Mixfile do
  use Mix.Project

  @repository "https://github.com/michalmuskala/plug_attack"

  def project do
    [
      app: :plug_attack,
      version: "0.4.3",
      elixir: "~> 1.4",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      description: description(),
      source_url: @repository,
      homepage_url: @repository,
      package: package(),
      deps: deps()
    ]
  end

  def application do
    [extra_applications: []]
  end

  defp description do
    """
    A plug building toolkit for blocking and throttling abusive requests.
    """
  end

  defp deps do
    [
      {:plug, "~> 1.0"},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.19", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @repository}
    ]
  end
end
