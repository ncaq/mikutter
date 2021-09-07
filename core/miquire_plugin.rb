# -*- coding: utf-8 -*-
require 'miquire'
require 'plugin'
require 'miquire_to_spec'

# プラグインのロードに関すること
module Miquire::Plugin
  class << self
    using Miquire::ToSpec
    include Enumerable

    # ロードパスの配列を返す。
    # ロードパスに追加したい場合は、以下のようにすればいい
    #
    #  Miquire::Plugin.loadpath << 'pathA' << 'pathB'
    def loadpath
      @loadpath ||= [] end

    # プラグインのファイル名(フルパス)で繰り返す。
    def each(&block)
      iterated = Set.new
      detected = []
      loadpath.reverse.each { |path|
        Dir[File.join(File.expand_path(path), '*')].each { |file|
          if FileTest.directory?(file) and FileTest.exist?(File.join(file, File.basename(file))+'.rb')
            file = File.join(file, File.basename(file))+'.rb'
          elsif not file.end_with?('.rb'.freeze)
            next end
          plugin_name = File.basename(file, '.rb')
          if not iterated.include? plugin_name
            iterated << plugin_name
            detected << file end } }
      detected.sort_by{ |a|
        [:bundle == get_kind(a) ? 0 : 1, a]
      }.each(&block) end

    def each_spec
      each{ |path|
        spec = get_spec path
        yield spec if spec } end

    def to_hash
      result = {}
      each_spec{ |spec|
        result[spec[:slug].to_sym] = spec }
      result end

    # 受け取ったパスにあるプラグインのスラッグを返す
    # ==== Args
    # [path] パス(String)
    # ==== Return
    # プラグインスラッグ(Symbol)
    def get_slug(path)
      type_strict path => String
      spec = get_spec(path)
      if spec
        spec[:slug]
      else
        File.basename(path, ".rb").to_sym end end

    # specファイルがあればそれを返す
    # ==== Args
    # [path] パス(String)
    # ==== Return
    # specファイルの内容か、存在しなければnil
    def get_spec(path)
      type_strict path => String
      plugin_dir = FileTest.directory?(path) ? path : File.dirname(path)
      spec_filename = File.join(plugin_dir, ".mikutter.yml")
      deprecated_spec = false
      unless FileTest.exist? spec_filename
        spec_filename = File.join(plugin_dir, "spec")
        deprecated_spec = true end
      if FileTest.exist? spec_filename
        YAML.load_file(spec_filename).symbolize
          .merge(kind: get_kind(path),
                 path: plugin_dir,
                 deprecated_spec: deprecated_spec)
      elsif FileTest.exist? path
        { slug: File.basename(path, ".rb").to_sym,
          kind: get_kind(path),
          path: plugin_dir,
          deprecated_spec: false } end end

    def get_spec_by_slug(slug)
      type_strict slug => Symbol
      to_hash[slug] end

    # プラグインがthirdpartyかbundleかを返す
    def get_kind(path)
      type_strict path => String
      if Environment::PLUGIN_PATH.any?(&path.method(:start_with?))
        :bundle
      else
        :thirdparty end end

    def load_all
      each_spec do |spec|
        load spec
      rescue Miquire::LoadError => e
        ::Plugin.call(:modify_activity,
                      kind: "system",
                      title: "#{spec[:slug]} load failed",
                      date: Time.new,
                      exception: e,
                      description: e.to_s)
      end
    end

    def satisfy_mikutter_version?(spec)
      if defined?(spec[:depends][:mikutter]) and spec[:depends][:mikutter]
        version = Environment::Version.new(*(spec[:depends][:mikutter].split(".").map(&:to_i) + ([0]*4))[0...4])
        if Environment::VERSION < version
          raise Miquire::LoadError, "plugin #{spec[:slug]}: #{Environment::NAME} version too old (#{spec[:depends][:mikutter]} required, but #{Environment::NAME} version is #{Environment::VERSION})"
          return false end end
      true
    end

    def depended_plugins(_spec, recursive: false)
      spec = _spec.to_spec
      unless spec
        error "spec #{_spec.inspect}"
        return false
      end
      if defined? spec[:depends][:plugin]
        if recursive
          local_depends = Array(spec[:depends][:plugin]).map{ |s| Array(s).first.to_sym }
          local_depends += local_depends.map {|s|
            depended_plugins(s, recursive: recursive).map{|d|d[:slug].to_sym}
          }.flatten
          local_depends.uniq.map{|d| d.to_spec }
        else
          Array(spec[:depends][:plugin]).map do |s|
            slug = Array(s).first.to_sym
            if slug
              slug.to_spec
            else
              slug end end end
      else
        [] end end

    def load(_spec)
      return false unless _spec
      spec = _spec.to_spec
      return false unless spec
      return true if ::Plugin.instance_exist?(spec[:slug])
      return false unless satisfy_mikutter_version?(spec)

      atomic do
        depended_plugins(spec).each do |depend|
          raise Miquire::LoadError, "plugin #{spec[:slug].inspect} was not loaded because dependent plugin #{depend.inspect} was not loaded." unless load(depend)
        rescue Miquire::LoadError => err
          raise Miquire::LoadError, "plugin #{spec[:slug].inspect} was not loaded because dependent plugin was not loaded. previous error is:\n#{err.to_s}"
        end

        notice "plugin loaded: " + File.join(spec[:path], "#{spec[:slug]}.rb")
        ::Plugin.create(spec[:slug].to_sym) do
          self.spec = spec end
        Kernel.load File.join(spec[:path], "#{spec[:slug]}.rb")
        if spec[:deprecated_spec]
          title = "#{spec[:slug]}: specファイルは非推奨になりました。"
          Plugin.call(:modify_activity,
                      { plugin: spec[:slug],
                        kind: "error",
                        title: title,
                        date: Time.now,
                        spec: spec,
                        description: "#{title}\n代わりに.mikutter.ymlを使ってください。"}) end
        true end
    end
  end
end
