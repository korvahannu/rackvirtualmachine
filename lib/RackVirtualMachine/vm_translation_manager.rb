# frozen_string_literal: true

require_relative('parser')
require_relative('translator')

module RackVirtualMachine
  # Manages the translation process from Hack bytecode to Hack assembly
  class VMTranslationManager
    def initialize(filepath, outputpath: nil)
      @parser = Parser.new(filepath)
      basename = File.basename(filepath, '.*')
      @translator = Translator.new(basename)
      @outputpath = "#{basename}.asm" if outputpath.nil?
    end

    def translate
      File.open(@outputpath, 'w') do |file|
        file.puts @translator.translate(@parser.command) while @parser.advance
      end
    end
  end
end
