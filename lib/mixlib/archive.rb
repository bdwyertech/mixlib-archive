require "mixlib/archive/tar"
require "mixlib/archive/version"
require "mixlib/log"
require "find"

module Mixlib
  class Archive
    class TarError < StandardError; end

    attr_reader :archiver
    alias_method :extractor, :archiver

    def self.archive_directory(path, archive, gzip: false, format: :tar, compression: :none)
      targets = Find.find(path).collect { |fn| fn }
      new(archive).create(targets, gzip: gzip)
    end

    def initialize(archive, empty: false)
      @empty = empty

      archive = File.expand_path(archive)
      begin
        # we prefer to use libarchive, which supports a great big pile o' stuff
        require "mixlib/archive/lib_archive"
        @archiver = Mixlib::Archive::LibArchive.new(archive)
      rescue LoadError
        # but if we can't use that, we'll fall back to ruby's native tar implementation
        @archiver = Mixlib::Archive::Tar.new(archive)
      end
    end

    class Log
      extend Mixlib::Log
    end

    Log.level = :error

    def create(files = [], gzip: false)
      archiver.create(files, gzip: gzip)
    end

    def extract(destination, perms: true, ignore: [])
      ignore = [/^\.$/, /\.{2}#{path_separator}/] + Array(ignore)

      create_and_empty(destination)

      archiver.extract(destination, perms: perms, ignore: ignore)
    end

    private

    BACKSLASH = '\\'.freeze

    def path_separator
      if Gem.win_platform?
        File::ALT_SEPARATOR || BACKSLASH
      else
        File::SEPARATOR
      end
    end

    def create_and_empty(destination)
      FileUtils.mkdir_p(destination)
      if @empty
        Dir.foreach(destination) do |entry|
          next if entry == "." || entry == ".."
          FileUtils.remove_entry_secure(File.join(destination, entry))
        end
      end
    end

  end
end
