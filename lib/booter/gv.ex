defmodule GV do
  @moduledoc """
  GV.draw generates a dot file to visualize the graph of boot steps.
  The output is similar to the image in Alvaro Videla's explanation of RabbitMQ's [boot process][1].

  To enable or disable this feature, use the module attribute switch `@draw_graph` in `booter.ex`.
  The list of boot steps is *hijacked* early, before any ordering or digraph generation,
  to help designing the boot graph regardless of eventual inconsistencies.

  The file generated can be used with [Graphviz][2]:

  ## visualize/edit the dot file with Graphviz:
  ```
  dotty priv/boot_graph.dot
  ```
  ## generate an image from the dot file
  ```
  dot -Tpng priv/boot_graph.dot -o priv/boot_graph.png
  ```
  [1]: https://raw.githubusercontent.com/videlalvaro/rabbit-internals/master/images/boot_steps.png
  [2]: http://www.graphviz.org/
  """
  require Logger 

  @priv "./priv"
  @filename "boot_graph.dot"
  
  @spec draw([Booter.Step.t, ...]) :: :ok | {:error, Elixir.File.posix | :badarg | :terminated}
  @doc "Write a file in dot format describing the graph of boot steps"
  def draw steps do
    check_priv.(@priv)
    {:ok, file} = File.open @priv <> "/" <> @filename, [:read, :write]
    IO.binwrite file, "digraph {\n"
    steps |> groups |> Enum.each &(IO.binwrite file, &1)
    IO.binwrite file, "\tsubgraph requires {\n"
    IO.binwrite file, "\t\tedge [dir=none]\n"
    steps |> requires |>  Enum.each &(IO.binwrite file, &1)
    IO.binwrite file, "\t}\n"
    IO.binwrite file, "\tsubgraph enables {\n"
    steps |> enables |> Enum.each &(IO.binwrite file, &1)
    IO.binwrite file, "\t}\n"
    IO.binwrite file, "}\n"
    File.close file
    Logger.info "Wrote #{@priv}/#{@filename}"
  end  
  
  defp check_priv, do: &(if !(File.dir? &1), do: File.mkdir &1)

  defp groups steps do
    steps|> Enum.filter_map &(!&1[:requires] && !&1[:enables]), &("\t\"#{&1[:name]}\" [shape=box, style=filled, color=green];\n")
  end

  defp requires steps do
    steps |> Enum.filter_map(&(&1[:requires]), &("\t\t\"#{&1[:requires]}\" -> \"#{&1[:name]}\" [label=requires];\n"))
  end

  defp enables steps do
    steps |> Enum.filter_map(&(&1[:enables]), &("\t\t\"#{&1[:name]}\" -> \"#{&1[:enables]}\" [label=enables];\n")) 
  end  
end
