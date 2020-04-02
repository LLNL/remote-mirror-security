# frozen_string_literal: true

###############################################################################
# Copyright (c) 2020, Lawrence Livermore National Security, LLC
# Produced at the Lawrence Livermore National Laboratory
# Written by Thomas Mendoza mendoza33@llnl.gov
# LLNL-CODE-801838
# All rights reserved
#
# This file is part of Remote Mirror Security:
# https://github.com/LLNL/remote-mirror-security
#
# SPDX-License-Identifier: MIT
###############################################################################

require 'logger'

# shared helper/utility methods
module SecureMirror
  module Codes
    OK = 0
    DENIED = 100
    CLIENT_ERROR = 200
    GENERAL_ERROR = 300
  end

  def self.class_from_string(klass)
    return Object.const_get(klass) unless klass.include?(':')

    klass.split('::').inject(Object) { |o, c| o.const_get c }
  end

  def self.setup_log_dir(log_file)
    log_dir = File.dirname(log_file)
    FileUtils.mkdir_p log_dir unless File.exist? log_dir
  end

  def self.init_logger(config)
    log_file = config[:log_file]
    setup_log_dir
    level = ENV['SM_LOG_LEVEL'] || config[:log_level] || Logger::INFO
    Logger.new(log_file, level: level)
  end
end
