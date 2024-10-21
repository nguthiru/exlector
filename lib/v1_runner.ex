defmodule V1Runner do
  def get_runner_registry do
   %{
      "metadata" => V1.MetadataRunner,
      "project" => V1.ProjectRunner
    }
  end

  def run(%{} = data) do
    IO.puts("Running V1 Runner")

    # Iterate through the keys of the data and run the corresponding runner
    for {key, value} <- data do
      case Map.get(get_runner_registry(), key) do
        nil -> IO.puts("Error: Runner not found for key #{key}")
        runner -> runner.run(value)
      end
    end
  end
end
