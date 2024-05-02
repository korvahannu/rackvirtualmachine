# frozen_string_literal: true

module RackVirtualMachine
  # Translates a parsed VM command into Hack assembly code
  class Translator
    SEGMENT_BASE_ADDRESSES = {
      'local' => 'LCL',
      'argument' => 'ARG',
      'this' => 'THIS',
      'that' => 'THAT',
      'temp' => 'TEMP'
    }.freeze
    THIS_THAT = %w[THIS THAT].freeze

    def initialize(filename)
      @filename = filename
      @command_number = 0
    end

    def translate(command)
      if command[:type] == CommandTypes::ARITHMETIC
        return get_command_arithmetic(command[:arg1])
      elsif [CommandTypes::PUSH, CommandTypes::POP].include?(command[:type])
        return get_command_push_pop(command[:type], command[:arg1], command[:arg2])
      end

      raise 'Unsupported command type'
    end

    # Gets an arithmetic command as a string and translates it to Hack assembly
    def get_command_arithmetic(command)
      @command_number += 1
      if command == 'add'
        return <<~ARM
          @SP
          M=M-1
          A=M
          D=M
          A=A-1
          D=D+M
          M=D
        ARM
      end
      if command == 'sub'
        return <<~ARM
          @SP
          M=M-1
          A=M
          D=M
          A=A-1
          D=M-D
          M=D
        ARM
      end
      if command == 'neg'
        return <<~ARM
          @SP
          A=M-1
          M=-M
        ARM
      end
      if command == 'eq'
        return <<~ARM
          @SP
          M=M-1
          A=M
          D=M
          A=A-1
          D=M-D
          @EQUAL.#{@command_number}
          D;JEQ
          @SP
          A=M-1
          M=0
          @END.#{@command_number}
          0;JMP
          (EQUAL.#{@command_number})
          @SP
          A=M-1
          M=-1
          (END.#{@command_number})
        ARM
      end
      if command == 'gt'
        return <<~ARM
          @SP
          M=M-1
          A=M
          D=M
          A=A-1
          D=M-D
          @GREATERTHAN.#{@command_number}
          D;JGT
          @SP
          A=M-1
          M=0
          @END.#{@command_number}
          0;JMP
          (GREATERTHAN.#{@command_number})
          @SP
          A=M-1
          M=-1
          (END.#{@command_number})
        ARM
      end
      if command == 'lt'
        return <<~ARM
          @SP
          M=M-1
          A=M
          D=M
          A=A-1
          D=M-D
          @LESSTHAN.#{@command_number}
          D;JLT
          @SP
          A=M-1
          M=0
          @END.#{@command_number}
          0;JMP
          (LESSTHAN.#{@command_number})
          @SP
          A=M-1
          M=-1
          (END.#{@command_number})
        ARM
      end
      if command == 'and'
        return <<~ARM
          @SP
          M=M-1
          A=M
          D=M
          A=A-1
          M=D&M
        ARM
      end
      if command == 'or'
        return <<~ARM
          @SP
          M=M-1
          A=M
          D=M
          A=A-1
          M=D|M
        ARM
      end
      if command == 'not'
        return <<~ARM
          @SP
          A=M-1
          M=!M
        ARM
      end

      raise "Unknown arithmetic command #{command}"
    end

    # Gets a command type (push or pop), segment, and an index and translates it to Hack assembly
    # E.g. (:C_PUSH, "local", 2)
    def get_command_push_pop(command_type, segment, index)
      @command_number += 1
      # pushes the value of segment[index] to the stack
      if command_type == CommandTypes::PUSH
        if segment == 'constant'
          return <<~PUSHCMD
            @#{index}
            D=A
            @SP
            A=M
            M=D
            @SP
            M=M+1
          PUSHCMD
        end
        if segment == 'static'
          return <<~PUSHCMD
            @#{@filename}.#{index}
            D=M
            @SP
            A=M
            M=D
            @SP
            M=M+1
          PUSHCMD
        end
        if %w[local argument this that].include?(segment)
          return <<~PUSHCMD
            @#{SEGMENT_BASE_ADDRESSES[segment]}
            D=M
            @#{index}
            D=D+A
            A=D
            D=M
            @SP
            A=M
            M=D
            @SP
            M=M+1
          PUSHCMD
        end
        if segment == 'pointer'
          return <<~PUSHCMD
            @3
            D=A
            @#{index}
            D=D+A
            A=D
            D=M
            @SP
            A=M
            M=D
            @SP
            M=M+1
          PUSHCMD
        end
        if segment == 'this'
          return <<~PUSHCMD
            @THIS
            D=M
            @SP
            A=M
            M=D
            @SP
            M=M+1
          PUSHCMD
        end
        if segment == 'that'
          return <<~PUSHCMD
            @THAT
            D=M
            @SP
            A=M
            M=D
            @SP
            M=M+1
          PUSHCMD
        end
        if segment == 'temp'
          return <<~PUSHCMD
            @#{SEGMENT_BASE_ADDRESSES[segment]}
            D=A
            @#{index}
            D=D+A
            A=D
            D=M
            @SP
            A=M
            M=D
            @SP
            M=M+1
          PUSHCMD
        end
        # pops the stack value and stores it in segment[index]
      elsif command_type == CommandTypes::POP
        if segment == 'static'
          return <<~POPCMD
            @SP
            M=M-1
            A=M
            D=M
            @#{@filename}.#{index}
            M=D
          POPCMD
        end
        if segment == 'local'
          return <<~POPCMD
            @LCL
            D=M
            @#{index}
            D=D+A
            @R13
            M=D
            @SP
            M=M-1
            A=M
            D=M
            @R13
            A=M
            M=D
          POPCMD
        end
        if segment == 'argument'
          return <<~POPCMD
            @ARG
            D=M
            @#{index}
            D=D+A
            @R13
            M=D
            @SP
            M=M-1
            A=M
            D=M
            @R13
            A=M
            M=D
          POPCMD
        end
        if segment == 'this'
          return <<~POPCMD
            @THIS
            D=M
            @#{index}
            D=D+A
            @R13
            M=D
            @SP
            M=M-1
            A=M
            D=M
            @R13
            A=M
            M=D
          POPCMD
        end
        if segment == 'that'
          return <<~POPCMD
            @THAT
            D=M
            @#{index}
            D=D+A
            @R13
            M=D
            @SP
            M=M-1
            A=M
            D=M
            @R13
            A=M
            M=D
          POPCMD
        end
        if segment == 'temp'
          return <<~POPCMD
            @5
            D=A
            @#{index}
            D=D+A
            @R13
            M=D
            @SP
            M=M-1
            A=M
            D=M
            @R13
            A=M
            M=D
          POPCMD
        end
        if segment == 'pointer'
          return <<~POPCMD
            @3
            D=A
            @#{index}
            D=D+A
            @R13
            M=D
            @SP
            M=M-1
            A=M
            D=M
            @R13
            A=M
            M=D
          POPCMD
        end
      end
      raise "Unknown push/pop command. Type: #{command}, segment: #{segment}, index: #{index}"
    end
  end
end
