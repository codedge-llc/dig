alias Mix.Tasks.Compile.Elixir, as: E
import Mix.Compilers.Elixir, only: [read_manifest: 2, source: 1, source: 2, module: 1]

module_sources =
  for manifest <- E.manifests(),
    manifest_data = read_manifest(manifest, ""),
    module(module: module, source: source) <- manifest_data,
    source = Enum.find(manifest_data, &match?(source(source: ^source), &1)),
    do: {module, source},
    into: %{}

all_modules = MapSet.new(module_sources, &elem(&1, 0))

file_references =
  Map.new module_sources, fn {module, source} ->
    source(runtime_references: runtime, compile_references: compile, source: file) = source
    compile_references =
      compile
      |> MapSet.new()
      |> MapSet.delete(module)
      |> MapSet.intersection(all_modules)
      |> Enum.filter(&module_sources[&1] != source)
      |> Enum.map(&{source(module_sources[&1], :source), "(compile)"})

    runtime_references =
      runtime
      |> MapSet.new()
      |> MapSet.delete(module)
      |> MapSet.intersection(all_modules)
      |> Enum.filter(&module_sources[&1] != source)
      |> Enum.map(&{source(module_sources[&1], :source), nil})

    {file, compile_references ++ runtime_references}
  end

graph = :digraph.new

files =
  file_references
  |> Map.keys
  |> Enum.sort

verts =
  file_references
  |> Enum.map(fn({key, _refs}) ->
      v = :digraph.add_vertex(graph, key)
      {key, v}
    end)
  |> Enum.into(%{})

for {key, refs} <- file_references do
  IO.inspect(refs, label: "refs")
  for {file, _} <- refs do
    IO.puts "Adding #{key} -> #{file}"
    :digraph.add_edge(graph, verts[key], verts[file])
  end
end

:digraph.vertices(graph)
|> IO.inspect

:digraph.edges(graph)
|> IO.inspect

:digraph.out_edges(graph, verts["lib/dig.ex"])
|> IO.inspect(label: "out")

defmodule Cycle do
  def print_cycle(cycle) do
    path = cycle |> Enum.join(" -> ")
    IO.puts """

    #{path}

    """
  end

  def get_cycles(graph, v, cycles) do
    case :digraph.get_cycle(graph, v) do
      false -> []
      [v1 | [v2 | rest]] = cycle -> []
    end
  end
end

for file <- files do
  case :digraph.get_cycle(graph, file) do
    false -> IO.puts(".")
    [v1 | [v2 | rest]] = cycle ->
      path = cycle |> Enum.join(" -> ")
      IO.puts """

      #{path}

      """
  end
end
