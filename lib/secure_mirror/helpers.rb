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

# shared helper/utility methods
module SecureMirror
  def self.class_from_string(klass)
    return Object.const_get(klass) unless klass.include?(':')

    klass.split('::').inject(Object) { |o, c| o.const_get c }
  end

  def self.setup_log_dir(log_file)
    log_dir = File.dirname(log_file)
    FileUtils.mkdir_p log_dir unless File.exist? log_dir
  end

  def self.init_logger(config)
    log_filename = config[:log_file]
    setup_log_dir(log_filename)
    log_file = File.open(log_filename, 'a')
    level = ENV['SM_LOG_LEVEL'] || config[:log_level] || Logger::INFO
    logger = Logger.new(log_file, level: level)

    logger.formatter = proc do |severity, time, _, msg|
      {
        level: severity,
        timestamp: time.to_s,
        gl_id: ENV['GL_ID'],
        gl_project_path: ENV['GL_PROJECT_PATH'],
        gl_protocol: ENV['GL_PROTOCOL'],
        gl_repository: ENV['GL_REPOSITORY'],
        gl_username: ENV['GL_USERNAME'],
        message: msg
      }.to_json + $/
    end

    return logger
  end

  def self.http_get(url, headers: {}, options: {})
    uri = URI.parse(url)
    http = http_client(uri, options)
    request = Net::HTTP::Get.new(uri.request_uri, headers)
    http.start { http.request(request) }
  end

  def self.http_client(uri, options)
    http = Net::HTTP.new(uri.host, uri.port)
    http.read_timeout = options[:read_timeout] || 15
    http.use_ssl = true if uri.is_a?(URI::HTTPS)
    http
  end
end
