# frozen_string_literal: true

require_relative('parser')
require_relative('translator')

module RackVirtualMachine
  # Manages the translation process from Hack bytecode to Hack assembly
  class VMTranslationManager
    def initialize(filepath)
      parser = Parser.new(filepath)
      basename = File.basename(filepath, '.*')
      translator = Translator.new(basename)
      outputpath = "#{basename}.asm"
      puts outputpath
      File.open(outputpath, 'w') do |file|
        while parser.advance
          if parser.command_type == CommandTypes::ARITHMETIC
            file.puts("// Arithmetic #{parser.arg1}")
            file.puts translator.get_command_arithmetic(parser.arg1)
          elsif [CommandTypes::PUSH, CommandTypes::POP].include?(parser.command_type)
            file.puts("// #{parser.command_type}, #{parser.arg1}, #{parser.arg2}")
            file.puts translator.get_command_push_pop(parser.command_type, parser.arg1, parser.arg2)
          end
        end
      end
    end
  end
end
