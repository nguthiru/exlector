defmodule Exlector do
  require Logger
  @moduledoc """
  Documentation for `Exlector`.
  """

  @doc """
  Hello world.

  ## Examples

      iex> Exlector.hello()
      :world

  """
  def hello do
    :world
  end

  def parse_yaml(file_path) do
    YamlElixir.read_from_file(file_path, atoms: true)
  end

  def parse_and_run(file_path) do
    case parse_yaml(file_path) do
      {:ok, %{"version" => 1} = data} ->
        Map.delete(data, "version")
        |> V1Runner.run()

      {:ok, %{"version" => _}} ->
        IO.puts("Error: Version not supported")

      {:error, reason} ->
        IO.puts("Error: #{reason}")
    end
  end

  # Allow running from the command line
  def main(args) do
    case args do
      [file_path] -> parse_and_run(file_path)
      _ -> Logger.error("Usage: exlector <file_path>")
    end
  end
end
