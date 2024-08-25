# frozen_string_literal: true

require_relative('command_types')

module RackVirtualMachine
  VM_ARITHMETIC_COMMANDS = %w[add sub neg eq gt lt and or not].freeze

  # Handles the parsing of a single .vm -file
  # Provides services for reading VM commands
  class Parser
    attr_reader :current_line, :current_line_numbers

    def initialize(filepath)
      @filepath = filepath
      @file = File.open(filepath)
      @current_line = nil
      @current_line_number = -1
      @current_lines_read = -1
      @command = []
    end

    def advance
      line = try_readline
      if line.nil?
        rewind
        return false
      end
      @current_line_number += 1
      @current_line = line
      @command = line.split(' ')
      true
    end

    def command_type
      return CommandTypes::ARITHMETIC if VM_ARITHMETIC_COMMANDS.include?(@command[0])
      return CommandTypes::PUSH if @command[0] == 'push'
      return CommandTypes::POP if @command[0] == 'pop'
      return CommandTypes::LABEL if @command[0] == 'label'
      return CommandTypes::GOTO if @command[0] == 'goto'
      return CommandTypes::IF if @command[0] == 'if-goto'

      raise "Unsupported VM command: #{@command[0].inspect}"
    end

    def arg1
      return nil if command_type == CommandTypes::RETURN

      return @command[0] if command_type == CommandTypes::ARITHMETIC

      @command[1]
    end

    def arg2
      unless [CommandTypes::PUSH, CommandTypes::POP, CommandTypes::FUNCTION, CommandTypes::CALL].include?(command_type)
        return nil
      end

      @command[2]
    end

    def command
      {
        type: command_type,
        arg1: arg1,
        arg2: arg2
      }
    end

    def rewind
      @file = File.open(@filepath)
      @current_line = nil
      @current_line_number = -1
      @current_lines_read = -1
      @command = []
    end

    private

    def try_readline
      line = nil
      while line.nil? || line.start_with?('//') || line.empty?
        begin
          line = @file.readline.chomp.strip
        rescue EOFError
          return nil
        end
        @current_lines_read += 1
      end
      line
    end
  end
end
