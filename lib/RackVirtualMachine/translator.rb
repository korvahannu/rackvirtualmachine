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
      @index = -1
    end

    # Gets an arithmetic command as a string and translates it to Hack assembly
    def get_command_arithmetic(command)
      @index += 1
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
          D=D-M
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
          @EQUAL.#{@index}
          D;JEQ
          @SP
          A=M-1
          M=0
          @END.#{@index}
          0;JMP
          (EQUAL.#{@index})
          @SP
          A=M-1
          M=-1
          (END.#{@index})
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
          @GREATERTHAN.#{@index}
          D;JGT
          @SP
          A=M-1
          M=0
          @END.#{@index}
          0;JMP
          (GREATERTHAN.#{@index})
          @SP
          A=M-1
          M=-1
          (END.#{@index})
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
          @LESSTHAN.#{@index}
          D;JLT
          @SP
          A=M-1
          M=0
          @END.#{@index}
          0;JMP
          (LESSTHAN.#{@index})
          @SP
          A=M-1
          M=-1
          (END.#{@index})
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
          M=M-1
          A=M
          M=!M
        ARM
      end

      raise "Unknown arithmetic command #{command}"
    end

    # Gets a command type (push or pop), segment, and an index and translates it to Hack assembly
    # E.g. (:C_PUSH, "local", 2)
    def get_command_push_pop(command_type, segment, index)
      @index += 1
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
            @#{@filename}.#{@index}
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
        if segment == 'pointer'
          return <<~PUSHCMD
            @#{THIS_THAT[index.to_i]}
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
            @#{@filename}.#{@index}
            M=D
          POPCMD
        end
        if %w[local argument this that temp].include?(segment)
          return <<~POPCMD
            @#{SEGMENT_BASE_ADDRESSES[segment]}
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
        if segment == 'pointer'
          return <<~POPCMD
            @SP
            M=M-1
            A=M
            D=M
            @#{THIS_THAT[index.to_i]}
            M=D
          POPCMD
        end
      end
      raise "Unknown push/pop command. Type: #{command}, segment: #{segment}, index: #{index}"
    end
  end
end
