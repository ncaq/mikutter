# frozen_string_literal: true

# プラグインでCLIコマンドを作成するためのDSLと、実行環境のセットアップ
module Prelude
  module DSL
    def namespace(name, &block)
      @namespaces ||= {}
      (@namespaces[name] ||= Namespace.new(self, name)).instance_eval(&block)
    end

    def command(name, description: nil, &block)
      @commands_dict ||= {}
      if @commands_dict[name]
        warn "already defined command `#{[full_name, name].compact.join(':')}`"
      end
      @commands_dict[name] = Command.new(self, name, action: block, description: description)
    end

    def commands
      @commands ||= commands_nocached
    end

    def commands_nocached
      Prelude.load_all
      [@namespaces&.values&.map(&:commands), @commands_dict&.values].compact.flatten.freeze
    end
  end

  class Namespace
    include DSL

    attr_reader :parent, :name

    def initialize(parent, name)
      @parent = parent
      @name = name
    end

    def full_name
      [parent.full_name, name].compact.join(':')
    end
  end

  class Command
    attr_reader :parent, :name, :description

    def initialize(parent, name, action:, description: nil)
      @parent = parent
      @name = name
      @action = action
      @description = description
      @plugin = Prelude.plugin_context
    end

    def full_name
      [parent.full_name, name].compact.join(':')
    end

    def execute
      ExecutionScope.new(full_name, @plugin).instance_eval(&@action)
    end
  end

  class ExecutionScope
    attr_reader :name, :spec

    def initialize(name, spec)
      @name = name
      @spec = spec
    end

    def load_plugin(*slugs)
      if slugs.empty?
        Miquire::Plugin.load(spec)
      else
        slugs.each(&Miquire::Plugin.method(:load))
      end
    end
  end

  class << self
    include DSL

    attr_accessor :plugin_context

    def full_name
      nil
    end

    def load_all
      Miquire::Plugin.each_spec do |spec|
        Prelude.plugin_context = spec
        Array(spec[:prelude]).each do |file|
          require File.join(spec[:path], file)
        end
      ensure
        Prelude.plugin_context = nil
      end
    end

    def execute!(command_name)
      require_relative '../utils'
      require 'boot/check_config_permission'

      cmd = Prelude.commands.find { |c| c.full_name == command_name }
      if cmd
        require 'fileutils'
        require 'lib/diva_hacks'
        require 'lib/lazy'
        require 'lib/reserver'
        require 'lib/timelimitedqueue'
        require 'lib/uithreadonly'
        require 'lib/weakstorage'
        require 'userconfig'
        cmd.execute
      else
        file = File.join(__dir__, "shell/#{command_name}.rb")
        if FileTest.exist?(file)
          require file
        else
          puts "no such command: #{command_name}"
        end
      end

      exit
    end
  end
end
