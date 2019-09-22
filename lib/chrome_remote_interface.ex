defmodule ChromeRemoteInterface do
  @moduledoc """
  Documentation for ChromeRemoteInterface.
  """

  alias ChromeRemoteInterface.PageSession

  @protocol_env_key :cri_protocol_version
  @protocol_versions ["1-2", "1-3", "tot"]
  @protocol_version Application.get_env(:chrome_remote_interface, :cri_protocol_version, "1-3")
  IO.puts(
    "Compiling ChromeRemoteInterface with Chrome DevTools Protocol version: '#{@protocol_version}'"
  )

  @doc """
  Gets the current version of the Chrome Debugger Protocol
  """
  def protocol_version() do
    @protocol_version
  end

  protocol =
    File.read!("priv/#{@protocol_version}/protocol.json")
    |> Jason.decode!()

  # Generate ChromeRemoteInterface.RPC Modules

  Enum.each(protocol["domains"], fn domain ->
    defmodule Module.concat(ChromeRemoteInterface.RPC, domain["domain"]) do
      @domain domain
      @moduledoc domain["description"]

      def experimental?(), do: @domain["experimental"]

      for command <- @domain["commands"] do
        name = command["name"]
        description = command["description"]

        arg_doc =
          command["parameters"]
          |> List.wrap()
          |> Enum.map(fn param ->
            "#{param["name"]} - <#{param["$ref"] || param["type"]}> - #{param["description"]}"
          end)

        @doc """
        #{description}

        Parameters:
        #{arg_doc}
        """
        def unquote(:"#{name}")(page_pid) do
          page_pid
          |> PageSession.execute_command(
            unquote("#{domain["domain"]}.#{name}"),
            %{},
            []
          )
        end

        def unquote(:"#{name}")(page_pid, parameters) do
          page_pid
          |> PageSession.execute_command(
            unquote("#{domain["domain"]}.#{name}"),
            parameters,
            []
          )
        end

        def unquote(:"#{name}")(page_pid, parameters, opts) when is_list(opts) do
          page_pid
          |> PageSession.execute_command(
            unquote("#{domain["domain"]}.#{name}"),
            parameters,
            opts
          )
        end
      end
    end
  end)
end
