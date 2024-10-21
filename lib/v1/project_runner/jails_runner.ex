defmodule V1.ProjectRunner.JailsRunner do

  use GenServer

  def start_link(%{
        working_dir: _working_directory
  } = _args) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def stop() do
    GenServer.stop(__MODULE__)
  end

  def init(_state) do
    {:ok, %{}}
  end
  def run(%{} = _data) do
    IO.puts("Running Jails Runner")
    # Sleep for 2 seconds to simulate a long running task
    Process.sleep(2000)
  end

end
