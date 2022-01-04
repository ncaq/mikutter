# frozen_string_literal: true

# プラグインでCLIコマンドを作成するためのDSLと、実行環境のセットアップ
module Prelude
  class NameError < RuntimeError; end

  module DSL
    def namespace(name, &block)
      @namespaces ||= {}
      if toplevel? && Prelude.plugin_context[:slug].to_s != name.to_s
        raise NameError, '最上位のnamespaceはプラグインのslugと同じ名前にする必要があります'
      end
      (@namespaces[name] ||= Namespace.new(self, name)).instance_eval(&block)
    end

    def command(name, description: nil, &block)
      @commands_dict ||= {}
      if !name || name.empty?
        raise NameError, 'command name cannot be empty'
      end
      if toplevel? && Prelude.plugin_context[:slug].to_s != name.to_s
        raise NameError, 'namespaceに含まれないcommandはプラグインのslugと同じ名前にする必要があります'
      end
      if @commands_dict[name]
        warn "already defined command `#{[full_name, name].compact.join(':')}`"
      end
      @commands_dict[name] = Command.new(self, name, action: block, description: description)
    end

    def commands
      @commands ||= commands_nocached
    end

    def commands_nocached
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

    private

    def toplevel?
      false
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

    def load_by_slug(slug)
      Prelude.plugin_context = spec = Miquire::Plugin.get_spec_by_slug(slug)
      return unless spec
      Array(spec[:prelude]).each do |file|
        require File.join(spec[:path], file)
      end
    ensure
      Prelude.plugin_context = nil
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

      load_by_slug(command_name.split(':', 2).first.to_sym)
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

    private

    def toplevel?
      true
    end
  end
end
