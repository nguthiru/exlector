defmodule V1.ProjectRunner.WorkflowRunner do
  require Logger
  use GenServer

  def start_link(
        %{
          working_dir: _working_directory
        } = args
      ) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(state) do
    {:ok, state}
  end

  def stop() do
    GenServer.stop(__MODULE__)
  end

  def run(workflows) do
    GenServer.call(__MODULE__, {:execute, workflows})
  end

  def execute_workflow(%{}=workflow, working_directory) do

    for {name, %{"command" => command, "runner" => runner}} <- workflow do
      Logger.debug("Running #{name} with command: #{command} using runner: #{runner}")
      {output, exit_code} = System.cmd(runner, ["-c", command], cd: working_directory)
      case exit_code do
        0 ->
          {:ok, output}
        _ ->
          {:error, output}
          raise "Error running command: #{command} with runner: #{runner}"
      end
    end

  end

  def handle_call({:execute, workflows}, _from, %{working_dir: working_directory}=state) do
    Enum.each(workflows, fn workflow -> execute_workflow(workflow, working_directory) end)
    {:reply, {:ok, "Workflow execution successful"}, state}
  end
end
