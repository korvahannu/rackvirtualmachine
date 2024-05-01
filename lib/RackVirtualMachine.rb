# frozen_string_literal: true

require_relative 'RackVirtualMachine/version'
require_relative 'RackVirtualMachine/vm_translation_manager'

# VirtualMachine for the Hack computer
module RackVirtualMachine
  filepath = ARGV[0]
  raise 'Please provide a filepath' if filepath.nil? || filepath.empty?
  raise 'Invalid filepath: Input file does not exist' unless File.exist?(filepath)

  VMTranslationManager.new(filepath)
end
