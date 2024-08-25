# frozen_string_literal: true

require_relative('parser')
require_relative('translator')

module RackVirtualMachine
  # Manages the translation process from Hack bytecode to Hack assembly
  class VMTranslationManager
    def initialize(filepath, outputpath: nil)
      @filepath = filepath
      @translator = Translator.new
      @outputpath = outputpath unless outputpath.nil?
      derivate_output_file_name(filepath) if outputpath.nil?
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
      File.open(@outputpath, 'w') do |output_file|
        files.each do |file|
          @translator.filename = get_file_name_for_translator(file)
          parser = Parser.new("#{@filepath}#{file}") if is_directory
          parser = Parser.new(file) unless is_directory
          output_file.puts @translator.translate(parser.command) while parser.advance
        end
      end
    end

    def get_files_to_compile(filepath)
      Dir.entries(filepath)
        .select { |f| f.end_with?(".vm")}
        .select { |f| File.file?("#{@filepath}#{f}") }
    end

    def get_file_name_for_translator(filepath)
      File.basename(filepath, '.*')
    end

    def derivate_output_file_name(filepath)
      if File.file?(filepath)
        @outputpath = "#{get_file_name_for_translator(filepath)}.asm"
      else
        @outputpath = "#{filepath.split('/').last}.asm"
      end
    end
  end
end
