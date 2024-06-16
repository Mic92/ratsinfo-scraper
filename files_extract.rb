#!/usr/bin/env/ruby

require 'open-uri'
require 'json'
require 'fileutils'
require 'socket'

DIR = "data/files"
Dir.foreach(DIR) do |json_name|
  next unless json_name =~ /\.json$/

  json_path = "#{DIR}/#{json_name}"
  json = JSON.load File.open(json_path)

  if json['mimeType'] == "application/pdf"
    pdf_path = json_path.sub(/\.json$/, ".pdf")
    txt_path = json_path.sub(/\.json$/, ".txt")
    next if File.exist? txt_path

    unless File.exist? pdf_path and json['fileName'].to_i % 14 != Time.new.yday % 14
      pdf_url = URI::parse json['downloadUrl'].sub(/^http:/, "https:")
      puts "GET #{pdf_url}"
      STDOUT.flush
      tries = 0
      begin
        pdf_url.open do |res|
          code = res.status[0]
          raise "HTTP #{code}" if code != "200"

          IO.copy_stream res, "#{pdf_path}.tmp"
          FileUtils.mv "#{pdf_path}.tmp", pdf_path
        end
      rescue
        p $!
        next
      end
    end
    print `pdftotext -enc UTF-8 #{pdf_path} && rm #{pdf_path}`
  else
    STDERR.puts "Unrecognized MIME type: #{json['mimeType']}"
  end
end
