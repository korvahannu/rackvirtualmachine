# frozen_string_literal: true

require_relative('parser')
require_relative('translator')

module RackVirtualMachine
  # Manages the translation process from Hack bytecode to Hack assembly
  class VMTranslationManager
    def initialize(filepath, output_path: nil)
      @filepath = filepath
      @translator = Translator.new
      setup_output_path(filepath, output_path)
    end

    def translate
      if File.file?(@filepath)
        translate_file(@filepath)
      else
        translate_files get_files_to_compile(@filepath)
      end
    end

    private

    def translate_file(file)
      translate_files([file], is_directory: false)
    end

    def translate_files(files, is_directory: true)
      raise 'Output path not defined, something went horribly wrong!' if @output_path == nil

      File.open(@output_path, 'w') do |output_file|
        output_file.puts @translator.bootstrap
        files.each do |file|
          @translator.filename = get_file_basename(file)
          parser = get_parser(file, is_directory)
          output_file.puts @translator.translate(parser.command) while parser.advance
        end
      end
    end

    def get_parser(file, is_directory)
      if is_directory
        Parser.new("#{@filepath}#{file}")
      else
        Parser.new(file)
      end
    end

    def get_files_to_compile(filepath)
      Dir.entries(filepath)
         .select { |f| f.end_with?(".vm") }
         .select { |f| File.file?("#{@filepath}#{f}") }
    end

    def get_file_basename(filepath)
      File.basename(filepath, '.*')
    end

    def setup_output_path(filepath, output_path)
      if @output_path.nil?
        derive_output_file_name(filepath)
      else
        @output_path = output_path
      end
    end

    def derive_output_file_name(filepath)
      basename = get_file_basename(filepath)
      if File.file?(filepath)
        @output_path = "#{basename}.asm"
      else
        @output_path = "#{basename.capitalize}.asm"
      end

      puts @output_path
    end
  end
end
