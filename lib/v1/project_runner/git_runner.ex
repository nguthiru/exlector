defmodule V1.ProjectRunner.GitRunner do
  require Logger
  @fields ["branch", "source"]
  use GenServer

  def start_link(
        %{
          working_dir: _working_directory
        } = args
      ) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(%{working_dir: working_dir} = state) do
    case directory_exists?(working_dir) do
      true ->
        # Delete the directory if it exists
        File.rm_rf!(working_dir)
        File.mkdir_p!(working_dir)
        {:ok, state}

      false ->
        # Create the directory if it doesn't exist
        File.mkdir_p!(working_dir)
        {:ok, state}
    end
  end

  def stop() do
    GenServer.stop(__MODULE__)
  end

  defp directory_exists?(directory) do
    File.dir?(directory)
  end

  def run(%{} = data) do
    GenServer.call(__MODULE__, {:run, data})
  end

  def handle_call({:run, data}, _from, state) do
    case execute(data, state) do
      {:ok, message} ->
        {:reply, {:ok, message}, state}

      {:error, error} ->
        {:reply, {:error, error}, state}
    end
  end

  def check_fields(data) do
    case Enum.all?(@fields, fn field -> Map.has_key?(data, field) end) do
      true ->
        {:ok, data}

      false ->
        required_fields = Enum.join(@fields, ", ")
        {:error, "Missing git fields, required fields are: #{required_fields}"}
    end
  end

  defp perform_git_clone(source, working_dir) do
    Logger.info("Git Runner: Cloning repository: #{source} in directory: #{working_dir}")
    {output, exit_code} = System.cmd("git", ["clone", source, "."], cd: working_dir)

    case exit_code do
      0 ->
        {:ok, output}

      _ ->
        {:error, output}
    end
  end

  defp fetch_git_repository(source, working_dir) do
    # check if the repository already exists in the working directory make a pull rather than clone
    perform_git_clone(source, working_dir)
  end

  defp perform_git_checkout(branch, directory) do
    Logger.info("Git Runner: Checking out branch: #{branch} in directory: #{directory}")
    {output, exit_code} = System.cmd("git", ["checkout", branch], cd: directory)

    case exit_code do
      0 ->
        {:ok, output}

      _ ->
        {:error, output}
    end
  end

  defp execute(%{} = data, %{working_dir: working_dir}) do
    case check_fields(data) do
      {:ok, %{"branch" => branch, "source" => source}} ->
        case fetch_git_repository(source, working_dir) do
          {:ok, _} ->
            case perform_git_checkout(
                   branch,
                   working_dir
                 ) do
              {:ok, _} ->
                Logger.info("Git Runner: Successfully cloned and checked out the repository")
                {:ok, "Git Runner: Successfully cloned and checked out the repository"}

              {:error, error} ->
                Logger.error("Git Runner: Error checking out the repository: #{error}")
                {:error, "Git Runner: Error checking out the repository: #{error}"}
            end

          {:error, error} ->
            Logger.error("Git Runner: Error cloning the repository: #{error}")
            {:error, "Git Runner: Error cloning the repository: #{error}"}
        end

      {:error, error} ->
        Logger.error("Git Runner: Error checking fields: #{error}")
        {:error, "Git Runner: Error checking fields: #{error}"}
    end
  end
end
