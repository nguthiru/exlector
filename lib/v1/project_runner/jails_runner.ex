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
    GenServer.call(__MODULE__, {:execute, jails},600000)
  end

  defp clone_base_dataset(name) do

    {output, exit_code} = System.cmd("zfs", ["clone", "zroot/jails/base@clean", "zroot/jails/#{name}"])

    case exit_code do
      0 ->
        Logger.info("ZFS dataset cloned successfully")

      _ ->
        Logger.error("Error cloning ZFS dataset: #{output}")
        {:error, "Error cloning ZFS dataset: #{output}"}
    end
  end

  defp create_mount_directory(name) do
    {output, exit_code} = System.cmd("mkdir", ["-p","/jails/#{name}"])

    case exit_code do
      0 ->
        Logger.info("Mount directory created successfully")

      _ ->
        Logger.error("Error creating mount directory: #{output}")
        {:error, "Error creating mount directory: #{output}"}
    end
  end

  defp mount_zfs_dataset(name) do
    {output, exit_code} = System.cmd("zfs", ["set", "mountpoint=/jails/#{name}", "zroot/jails/#{name}"])

    case exit_code do
      0 ->
        Logger.info("ZFS dataset mounted successfully")

      _ ->
        Logger.error("Error mounting ZFS dataset: #{output}")
        {:error, "Error mounting ZFS dataset: #{output}"}
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
        File.write!("/etc/jail.conf.d/#{name}.conf", template, [:write])

      {:error, error} ->
        Logger.error("Error creating jails configuration: #{error}")
        {:error, "Error creating jails configuration: #{error}"}
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

  defp install_dependency(name, %{"name" => name}=_dependecy) do
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

  defp install_dependencies(name, %{"pkg"=> dependencies}) do
    # Install dependencies
    Enum.each(dependencies, fn dependency -> install_dependency(name, dependency) end)
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
        clone_base_dataset(name)
        create_mount_directory(name)
        mount_zfs_dataset(name)
        create_jails_config(name, jails["config"])
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
