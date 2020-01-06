# -*- coding: utf-8 -*-
# コマンドラインオプションを受け取る

require 'optparse'

module Mopt
  extend Mopt

  @opts = {
    error_level: 1 }

  def confroot
    @opts[:confroot] || ENV['MIKUTTER_CONFROOT'] || File.join(Dir.home, '.mikutter')
  end

  def method_missing(key)
    scope = class << self; self end
    scope.__send__(:define_method, key){ @opts[key.to_sym] }
    @opts[key.to_sym] end

  def parse(argv=ARGV, exec_command: false)
    unless argv.is_a? OptionParser::Arguable
      argv.extend(OptionParser::Arguable) end
    OptionParser.new do |opt|
      opt.banner = "Usage: mikutter.rb [options] [command]"
      opt.separator "options are:"
      opt.on('--debug', 'Debug mode (for development)') { |v|
        @opts[:debug] = true
        @opts[:error_level] = v.is_a?(Integer) ? v : 3 }
      opt.on('--profile', 'Profiling mode (for development)') { @opts[:profile] = true }
      opt.on('--skip-version-check', 'Skip library and environment version check') { @opts[:skip_version_check] = true }
      opt.on('-p', '--plugin=', 'Load specified plugins and depended plugins (comma separated)'){ |plugins| @opts[:plugin] = (@opts[:plugin]||[]).concat plugins.split(",") }
      opt.on('--confroot=', 'set confroot directory') { |v|
        @opts[:confroot] = File.expand_path(v) }
      opt.on('--daemon', '-d'){
        Process.daemon(true) }
      opt.on('--clean', 'delete all caches and duplicated files') { |v|
        require 'fileutils'
        require_relative '../utils'
        require 'environment'
        puts "delete "+File.expand_path(Environment::TMPDIR)
        FileUtils.rm_rf(File.expand_path(Environment::TMPDIR))
        puts "delete "+File.expand_path(Environment::LOGDIR)
        FileUtils.rm_rf(File.expand_path(Environment::LOGDIR))
        puts "delete "+File.expand_path(Environment::CONFROOT)
        FileUtils.rm_rf(File.expand_path(File.join(Environment::CONFROOT, 'icons')))
        puts "delete "+File.expand_path(Environment::CACHE)
        FileUtils.rm_rf(File.expand_path(Environment::CACHE))
        exit }
      opt.on('-v', '--version', "Show mikutter version"){ |v|
        require 'fileutils'
        require_relative '../utils'
        require 'environment'
        puts Environment::NAME + ' ' +  Environment::VERSION.to_s
        exit }
      opt.on('-h', '--help', "Show this message"){
        puts opt
        puts "command are:"
        puts "        generate [plugin_slug]       generate plugin template at ~/.mikutter/plugin/"
        puts "        spec [directory]             generate plugin spec. ex) mikutter spec ~/.mikutter/plugin/test"
        puts "        makepot                      generate .pot file all plugins."
        puts "        plugin_depends               Output plugin dependencies."
        exit }

      opt.parse!(argv)

      if exec_command and argv[0]
        require_relative '../utils'
        require 'boot/check_config_permission'
        file = File.join(__dir__, "shell/#{argv[0]}.rb")
        if FileTest.exist?(file)
          require file
        else
          puts "no such command: #{argv[0]}"
        end
        exit
      end
    end
  end
end
