# frozen_string_literal: true

module RackVirtualMachine
  # Translates a parsed VM command into Hack assembly code
  class Translator
    private_class_method :new

    SEGMENT_BASE_ADDRESSES = {
      "local" => "LCL",
      "argument" => "ARG",
      "this" => "THIS",
      "that" => "THAT",
      "temp" => "TEMP"
    }.freeze

    class << self
      # Gets an arithmetic command as a string and translates it to Hack assembly
      def get_command_arithmetic(command) end

      # Gets a command type (push or pop), segment, and an index and translates it to Hack assembly
      # E.g. (:C_PUSH, "local", 2)
      def get_command_push_pop(command_type, segment, index)
        # pushes the value of segment[index] to the stack
        if command_type == CommandTypes::PUSH
          if segment == "constant"
            return <<~PUSHCMD
              @#{index}
              D=A
              @SP
              A=M
              M=D
              @SP
              M=M+1
            PUSHCMD
          elsif command_type == CommandTypes::POP
            # todo
          end
        end
      end
    end
  end
end
