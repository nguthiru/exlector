defmodule V1.ProjectRunner do
  require Logger
  alias V1.ProjectRunner.WorkflowRunner
  alias V1.ProjectRunner.JailsRunner
  alias V1.ProjectRunner.GitRunner

  def fields do
    ["git", "jails", "name"]
  end

  defp check_fields(data) do
    case Enum.all?(fields(), fn field -> Map.has_key?(data, field) end) do
      true ->
        {:ok, data}

      false ->
        {:error, "Missing fields"}
    end
  end

  def execute_git(data) do
    case GitRunner.start_link(%{working_dir: data["working_dir"]}) do
      {:ok, _pid} ->
        case GitRunner.run(data["git"]) do
          {:ok, _} ->
            Logger.debug("Execution Successful. Stopping Git Runner")
            GitRunner.stop()
            {:ok, "Git execution successful"}

          {:error, error} ->
            Logger.error("Error executing git runner: #{inspect(error)}")
            {:error, error}
        end

      {:error, error} ->
        Logger.error("Error executing git runner: #{inspect(error)}")
        {:error, error}
    end
  end

  def execute_workflow(data) do
    case data |> Map.has_key?("workflow") do
      true ->
        case WorkflowRunner.start_link(%{working_dir: data["working_dir"]}) do
          {:ok, _pid} ->
            WorkflowRunner.run(data["workflow"])
            WorkflowRunner.stop()
            {:ok, "Workflow execution successful"}
          {:error, error} ->
            Logger.error("Error executing workflow runner: #{inspect(error)}")
            {:error, error}
        end

      false ->
        {:ok, "Workflow not present"}
    end
  end

  def execute_jails(data) do
    case JailsRunner.start_link(%{working_dir: data["working_dir"]}) do
      {:ok, _pid} ->
        JailsRunner.run(data["jails"])
        JailsRunner.stop()

      {:error, error} ->
        Logger.error("Error executing jails runner: #{inspect(error)}")
        raise error
    end
  end

  def run(%{} = data) do
    # Ensure all the fields are present before running individual learners
    case check_fields(data) do
      {:ok, data} ->
        case execute_git(data) do
          {:ok, _} ->
            Logger.debug("Git execution successful")
            case execute_workflow(data) do
              {:ok, _} ->
                Logger.debug("Workflow execution successful")
                execute_jails(data)
              {:error, error} ->
                Logger.error("Error executing workflow runner: #{inspect(error)}")
            end

          {:error, error} ->
            Logger.error("Error executing git runner: #{inspect(error)}")
        end

      {:error, error} ->
        raise error
    end
  end
end
