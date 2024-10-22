defmodule V1.ProjectRunner.JailsRunner do
  require Logger
  use GenServer

  def start_link(
        %{
          working_dir: _working_directory
        } = _args
      ) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def stop() do
    GenServer.stop(__MODULE__)
  end

  def init(_state) do
    {:ok, %{}}
  end

  def run(jails) do
    GenServer.call(__MODULE__, {:execute, jails})
  end

  defp create_zfs_dataset(name) do
    # Create a ZFS dataset for the project
    # This is a long running task
    Logger.debug("Creating ZFS dataset for project: #{name}")
    # Check if directory exists
    case File.dir?("jails/#{name}") do
      true -> Logger.info("Skipping ZFS dataset creation as directory exists")
      false -> File.mkdir_p!("jails/#{name}")
    end

    {output, exit_code} =
      System.cmd("zfs", ["create", "-o", "mountpoint=/jails/#{name}", "zroot/jails/#{name}"])

    case exit_code do
      0 ->
        Logger.info("ZFS dataset created successfully")

      _ ->
        Logger.error("Error creating ZFS dataset: #{output}")
        {:error, "Error creating ZFS dataset: #{output}"}
    end
  end

  defp create_jails_config(name, %{
         "interface" => interface,
         "ip" => %{"inherit" => inherit?} = ip_config
       }) do
    template = """
    #{name} {

    exec.start = "/bin/sh /etc/rc";
    exec.stop = "/bin/sh /etc/rc.shutdown";
    exec.clean;
    mount.devfs;

    host.hostname = #{name}.local;
    path = /jails/#{name};
    allow.raw_sockets;
    persist;

    interface = #{interface};

    }

    """

    add_ip_config =
      case inherit? do
        true ->
          # Add a ip4 inherit = inherit to the template
          template = template <> "ip4 = inherit;\n"
          {:ok, template}

        false ->
          case Map.has_key?(ip_config, "address") do
            true ->
              # Add a ip4 address = address to the template
              template = template <> "ip4.addr = #{ip_config["address"]};\n"
              {:ok, template}

            false ->
              {:error, "Missing address in ip configuration"}
          end
      end

    case add_ip_config do
      {:ok, template} ->
        Logger.info("Jails configuration created successfully")
        File.write!("jails/#{name}.conf", template, [:write])

      {:error, error} ->
        Logger.error("Error creating jails configuration: #{error}")
        {:error, "Error creating jails configuration: #{error}"}
    end
  end

  defp install_bsd_on_jails(name) do
    {output, exit_code} = System.cmd("bsdinstall", ["jail", "jails/#{name}"])

    case exit_code do
      0 ->
        Logger.info("BSD installation successful")

        {:ok, "BSD installation successful"}

      _ ->
        Logger.error("Error installing BSD: #{output}")
        {:error, "Error installing BSD: #{output}"}
    end
  end

  defp start_jails(name) do
    {output, exit_code} = System.cmd("service", ["jail", "start", name])

    case exit_code do
      0 ->
        Logger.info("Jails started successfully")
        {:ok, "Jails started successfully"}

      _ ->
        Logger.error("Error starting jails: #{output}")
        {:error, "Error starting jails: #{output}"}
    end
  end

  defp install_dependency(name, %{"name" => name}) do
    # Command is jexec {name} pkg install {name} -y
    {output, exit_code} = System.cmd("jexec", [name, "pkg", "install", name, "-y"])

    case exit_code do
      0 ->
        Logger.info("Dependency #{name} installed successfully")
        {:ok, "Dependency #{name} installed successfully"}

      _ ->
        Logger.error("Error installing dependency #{name}: #{output}")
        {:error, "Error installing dependency #{name}: #{output}"}
    end
  end

  defp install_dependencies(name, [] = dependecies) do
    # Install dependencies
    Enum.each(dependecies, fn dependency -> install_dependency(name, dependency) end)
  end

  defp copy_file(name, %{"from" => from, "to" => to}) do
    {output, exit_code} = System.cmd("cp", [from, "jails/#{name}/#{to}"])

    case exit_code do
      0 ->
        Logger.info("File copied successfully")
        {:ok, "File copied successfully"}

      _ ->
        Logger.error("Error copying file: #{output}")
        {:error, "Error copying file: #{output}"}
    end
  end

  defp copy_files(name, [] = directives) do
    Enum.each(directives, fn directive -> copy_file(name, directive) end)
  end

  defp execute_command(name, command) do
    System.cmd("jexec", [name, command])
  end

  def handle_call({:execute, jails}, _from, state) do
    case Map.has_key?(jails, "name") do
      true ->
        name = jails["name"]
        create_zfs_dataset(name)
        create_jails_config(name, jails["config"])
        install_bsd_on_jails(name)
        start_jails(name)

        case Map.has_key?(jails, "dependencies") do
          true ->
            install_dependencies(name, jails["dependencies"])

          false ->
            :ok
        end

        case Map.has_key?(jails, "copy") do
          true ->
            copy_files(name, jails["copy"])

          false ->
            :ok
        end

        case Map.has_key?(jails, "commands") do
          true ->
            Enum.each(jails["commands"], fn command -> execute_command(name, command) end)

          false ->
            :ok
        end

        {:reply, {:ok, "Jails execution successful"}, state}
    end
  end
end
