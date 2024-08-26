# frozen_string_literal: true

module RackVirtualMachine
  # Translates a parsed VM command into Hack assembly code
  class Translator
    attr_accessor :filename

    SEGMENT_BASE_ADDRESSES = {
      'local' => 'LCL',
      'argument' => 'ARG',
      'this' => 'THIS',
      'that' => 'THAT',
      'temp' => 'TEMP'
    }.freeze
    THIS_THAT = %w[THIS THAT].freeze

    def initialize
      @filename = nil
      @command_number = 0
      @return_label = 0
    end

    def translate(command)
      type = command[:type]
      arg1 = command[:arg1]
      arg2 = command[:arg2]

      case type
      when CommandTypes::ARITHMETIC
        get_command_arithmetic(arg1)
      when CommandTypes::PUSH, CommandTypes::POP
        get_command_push_pop(type, arg1, arg2)
      when  CommandTypes::LABEL
        get_command_label(arg1)
      when CommandTypes::GOTO
        get_command_goto(arg1)
      when CommandTypes::IF
        get_command_if(arg1)
      when CommandTypes::FUNCTION
        get_command_function(arg1, arg2)
      when CommandTypes::RETURN
        get_command_return
      when CommandTypes::CALL
        get_command_call(arg1, arg2)
      else
        raise 'Unsupported command type'
      end
    end

    def bootstrap
      <<~BOOTSTRAP
      @256
      D=A
      @SP
      M=D
      #{get_command_call('Sys.init', 0)}
      BOOTSTRAP
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

    # Gets the necessary bootstrap
    def finalize_and_bootstrap
    end

    def get_command_label(label)
      "(#{label})"
    end

    def get_command_goto(label)
      <<~GOTO
      @#{label}
      0;JMP
      GOTO
    end

    # if the topmost value in stack is not 0, jump, otherwise continue
    def get_command_if(label)
      <<~IFGOTO
      @SP
      M=M-1
      A=M
      D=M
      @#{label}
      D;JNE
      IFGOTO
    end

    def get_command_function(function_name, number_of_args)
      arg_count = Integer(number_of_args)
      result = "(#{function_name})"
      result << "\n" if arg_count > 0

     arg_count.times do |i|
        result << <<~EOS
        @SP
        A=M
        M=0
        @SP
        M=M+1
        EOS
      end

      result
    end

    def get_command_return
      <<~RETURN
      @LCL
      D=M
      @frame // sets frame to LCL
      M=D
      @5
      D=D-A
      A=D
      D=M
      @returnaddress
      M=D // saves return address to @returnaddress
      @SP
      M=M-1
      A=M
      D=M // D = return value
      @ARG
      A=M
      M=D // sets the return value to ARG
      @ARG
      D=M+1
      @SP
      M=D // sets stack pointer to arg + 1
      @frame
      D=M
      @1
      D=D-A
      A=D
      D=M
      @THAT
      M=D // restore THAT
      @frame
      D=M
      @2
      D=D-A
      A=D
      D=M
      @THIS
      M=D // restore THIS
      @frame
      D=M
      @3
      D=D-A
      A=D
      D=M
      @ARG
      M=D // restores ARG
      @frame
      D=M
      @4
      D=D-A
      A=D
      D=M
      @LCL
      M=D // restores LCL
      @returnaddress
      A=M
      0;JMP
      RETURN
    end

    def get_command_call(function_name, number_of_args)
      label = "RETURN$#{@return_label = @return_label + 1}"
      <<~CALL
      @#{label}
      D=A
      @SP
      A=M
      M=D // push return address
      @SP
      M=M+1
      @LCL
      D=M
      @SP
      A=M
      M=D // push LCL
      @SP
      M=M+1
      @ARG
      D=M
      @SP
      A=M
      M=D // push ARG
      @SP
      M=M+1
      @THIS
      D=M
      @SP
      A=M
      M=D // push THIS
      @SP
      M=M+1
      @THAT
      D=M
      @SP
      A=M
      M=D // push THAT
      @SP
      M=M+1
      @SP
      D=M
      @#{5+Integer(number_of_args)}
      D=D-A
      @ARG
      M=D // reposition ARG
      @SP
      D=M
      @LCL
      M=D // reposition LCL
      @#{function_name}
      0;JMP // jump to function execution
      (#{label}) // write return address label
      CALL
    end
  end
end
