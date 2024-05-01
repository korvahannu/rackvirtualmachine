# frozen_string_literal: true

require_relative('parser')
require_relative('translator')

module RackVirtualMachine
  # Manages the translation process from Hack bytecode to Hack assembly
  class VMTranslationManager
    def initialize(filepath)
      parser = Parser.new(filepath)
      translator = Translator.new(File.basename(filepath, ".*"))
      while parser.advance
        puts "Command----"
        if parser.command_type == CommandTypes::ARITHMETIC
          puts translator.get_command_arithmetic(parser.arg1)
        elsif [CommandTypes::PUSH, CommandTypes::POP].include?(parser.command_type)
          puts translator.get_command_push_pop(parser.command_type, parser.arg1, parser.arg2)
        end
      end
    end
  end
end
