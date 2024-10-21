defmodule V1.ProjectRunner.WorkflowRunner do
  require Logger
  use GenServer

  @fields ["test", "build"]

  def start_link(
        %{
          working_dir: _working_directory
        } = _args
      ) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(state) do
    {:ok, state}
  end

  def stop() do
    GenServer.stop(__MODULE__)
  end

  def run([] = workflows) do
    GenServer.call(__MODULE__, {:execute, data})
  end

  def execute_workflow(%{key => %{"command"=> command} }) do
    case Enum.member?(key, @fields) do
      true ->
        Logger.debug("Executing workflow: #{command}")
        System.cmd("sh", ["-c", command])

      false ->
        Logger.error("Invalid workflow for: #{key}")
        {:error, "Invalid workflow key"}
    end
  end

  def handle_call({:execute, workflows}, _from, state) do
    for workflow <- workflows do
      case execute_workflow(workflow) do
        {:ok, _} ->
          Logger.debug("Workflow execution successful")

        {:error, error} ->
          Logger.error("Error executing workflow: #{inspect(error)}")
      end
    end

    {:reply, {:ok, "Workflow execution successful"}, state}
  end
end
