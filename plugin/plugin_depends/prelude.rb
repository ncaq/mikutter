# frozen_string_literal: true

using Miquire::ToSpec

Prelude.command :plugin_depends, description: 'Output plugin dependencies.' do
  escape = ->(v) do
    if /[^\w]/.match?(v)
      '"%{v}"' % { v: v.gsub('"', '\"') }
    else
      v
    end
  end

  writer = ->(node, graph, spec) do
    depends = Miquire::Plugin.depended_plugins(spec)
    if (depends || []).empty?
      graph.puts "  #{escape.(spec[:slug])};"
    else
      depends.zip(Array(spec.dig(:depends, :plugin))).each do |depend, src|
        if depend
          graph.puts "  #{escape.(spec[:slug])} -> #{escape.(depend[:slug])};"
        else
          id = src.hash
          node.puts "  #{id} [label = #{escape.(src.inspect)}, shape = box, fillcolor = \"#FFCCCC\", style = \"solid,filled\"];"
          graph.puts "  #{escape.(spec[:slug])} -> #{id};"
        end
      end
    end
  end

  puts 'digraph mikutter_plugin {'

  graph_buf = StringIO.new(String.new, 'r+')

  if Array(Mopt.plugin).empty?
    Miquire::Plugin.each_spec(&writer.curry.($stdout, graph_buf))
  else
    available = Array(Mopt.plugin).inject(Set.new(Array(Mopt.plugin))) do |depends, depend_slug|
      Miquire::Plugin.depended_plugins(depend_slug, recursive: true).each do |spec|
        depends << spec[:slug]
      end
    end
    available.map(&:to_spec).each(&writer.curry.($stdout, graph_buf))
  end

  graph_buf.rewind
  $stdout.write graph_buf.read

  puts '}'
end
