defmodule Mix.Tasks.Dig do
  use Mix.Task

  def run(_args) do
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
      for {file, _} <- refs do
        :digraph.add_edge(graph, verts[key], verts[file])
      end
    end

    for file <- files do
      case :digraph.get_cycle(graph, file) do
        false ->
          IO.ANSI.green <> "." <> IO.ANSI.reset
          |> IO.write
        _cycle ->
          IO.ANSI.red <> "X" <> IO.ANSI.reset
          |> IO.write
      end
    end

    IO.write("\n\n")

    for file <- files do
      case :digraph.get_cycle(graph, file) do
        false -> nil
        [v1 | [v2 | rest]] = cycle ->
          path = cycle |> Enum.join(" -> ")
          IO.puts """
          == #{file} ==
          #{path}

          """
      end
    end
  end
end
