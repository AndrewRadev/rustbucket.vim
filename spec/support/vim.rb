require 'fileutils'

module Support
  module Vim
    def write_file(filename, string)
      if !File.exists?(File.dirname(filename))
        FileUtils.mkdir_p(File.dirname(filename))
      end

      File.open(filename, 'w') { |f| f.write(string + "\n") }
    end

    def edit_file(filename, string)
      write_file(filename, string)
      vim.edit!(filename)
    end
  end
end
