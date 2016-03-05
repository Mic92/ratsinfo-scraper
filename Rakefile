$:.unshift File.expand_path(File.join(File.dirname(__FILE__), 'lib'))

require 'scrape'
require 'rake/testtask'
require 'json'
require 'pry'
require 'fileutils'

CALENDAR_URI = "http://ratsinfo.dresden.de/si0040.php?__cjahr=%d&__cmonat=%s"
SESSION_URI = "http://ratsinfo.dresden.de/to0040.php?__ksinr=%d"
DOWNLOAD_PATH = ENV["DOWNLOAD_PATH"] || File.join(File.dirname(__FILE__), "data")

VORLAGEN_LISTE_URI = "http://ratsinfo.dresden.de/vo0042.php?__cwpall=1"
VORLAGE_URI = "http://ratsinfo.dresden.de/vo0050.php?__kvonr=%s"

ANFRAGEN_LISTE_URI = "http://ratsinfo.dresden.de/ag0041.php?__cwpall=1"
ANFRAGE_URI = "http://ratsinfo.dresden.de/ag0050.php?__kagnr=%s"

GREMIEN_LISTE_URI = "http://ratsinfo.dresden.de/gr0040.php?__cwpall=1&"

PERSON_URI = "http://ratsinfo.dresden.de/kp0050.php?__cwpall=1&__kpenr=%d"

FILE_URI = "http://ratsinfo.dresden.de/getfile.php?id=%s&type=do"

directory DOWNLOAD_PATH

scrape_start_date = Date.new(2009,8)
scrape_end_date = Time.now.to_date

task :default => [:scrape_sessions]

desc "Scrape Documents from http://ratsinfo.dresden.de with a minmal timerange"
task :testmonth do
  scrape_start_date = Date.new(2009, 8)
  scrape_end_date  = Date.new(2009, 8)
  Rake::Task["scrape_sessions"].invoke
end


desc "Scrape Documents from http://ratsinfo.dresden.de"
task :scrape => [
       :scrape_gremien,
       :scrape_people,
       :scrape_anfragen, :scrape_vorlagen,
       :scrape_sessions,
       :fetch_meetings_anfragen,
       :fetch_files
     ]

task :scrape_gremien do
  Scrape::GremienListeScraper.new(GREMIEN_LISTE_URI).each do |organization|
    puts "[#{organization.id}] #{organization.name}"
    organization.save_to File.join(DOWNLOAD_PATH, "gremien", "#{organization.id}.json")
  end
end

task :scrape_people do
  Scrape::PeopleScraper.new(PERSON_URI).each do |person|
    puts "[#{person.id}] #{person.name}"
    person.save_to File.join(DOWNLOAD_PATH, "persons", "#{person.id}.json")
  end
end

task :scrape_sessions do
  raise "download path '#{DOWNLOAD_PATH}' does not exists!" unless Dir.exists?(DOWNLOAD_PATH)
  date_range = (scrape_start_date..scrape_end_date).select {|d| d.day == 1}
  date_range.each do |date|
    uri = sprintf(CALENDAR_URI, date.year, date.month)
    s = Scrape::ConferenceCalendarScraper.new(uri)
    s.each do |session_id|
      session_path = File.join(DOWNLOAD_PATH, "meetings", session_id)
      if Dir.exists?(session_path)
        puts("#skip #{session_id}")
        next
      end
      puts "from date: #{date}"
      mkdir_p(session_path)
      session_url = sprintf(SESSION_URI, session_id)

      meeting = Scrape::SessionScraper.new(session_url).scrape
      meeting.id = session_id
      pp meeting

      meeting.save_to File.join(DOWNLOAD_PATH, "meetings", "#{meeting.id}.json")
      meeting.persons.each do |person|
        persons_path = File.join(DOWNLOAD_PATH, "persons", "#{person.id}.json")
        if not File.exists?(persons_path)
            person.save_to persons_path
        end
      end
      meeting.files.each do |file|
        file.save_to File.join(DOWNLOAD_PATH, "files", "#{file.id}.json")
      end
    end
  end
end

task :scrape_vorlagen do
  Scrape::VorlagenListeScraper.new(VORLAGEN_LISTE_URI).each do |paper|
    id = paper.id
    paper = Scrape::PaperScraper.new(sprintf(VORLAGE_URI, id)).scrape
    paper.id = id  # Restore id

    puts "Vorlage #{paper.id} [#{paper.shortName}] #{paper.name}"
    paper.save_to File.join(DOWNLOAD_PATH, "vorlagen", "#{paper.id}.json")
    paper.files.each do |file|
      file.save_to File.join(DOWNLOAD_PATH, "files", "#{file.id}.json")
    end
  end
end

task :scrape_anfragen do
  Scrape::AnfragenListeScraper.new(ANFRAGEN_LISTE_URI).each do |paper|
    puts "Anfrage #{paper.id} [#{paper.shortName}] #{paper.name}"
    paper.save_to File.join(DOWNLOAD_PATH, "anfragen", "#{paper.id}.json")
    paper.files.each do |file|
      file.save_to File.join(DOWNLOAD_PATH, "files", "#{file.id}.json")
    end
  end
end


desc "Durchsucht alle Meetings nach weiteren Anfragen"
task :fetch_meetings_anfragen do
  Dir.glob(File.join(DOWNLOAD_PATH, "meetings", "*.json")) do |filename|
    meeting = OParl::Meeting.load_from(filename)
    meeting.agendaItem.each do |agenda_item|
      id = agenda_item.consultation
      next unless id
      paper_path = File.join(DOWNLOAD_PATH, "vorlagen", "#{id}.json")
      next if File.exist? paper_path

      paper = Scrape::PaperScraper.new(sprintf(VORLAGE_URI, id)).scrape
      paper.id = id  # Restore id

      puts "Vorlage #{paper.id} [#{paper.shortName}] #{paper.name}"
      paper.save_to paper_path
      paper.files.each do |file|
        file.save_to File.join(DOWNLOAD_PATH, "files", "#{file.id}.json")
      end
    end
  end
end

desc "Ensure all known PDF files are fetched, even those not included in Meetings but referenced by Papers"
task :fetch_files do
  path = File.join(DOWNLOAD_PATH, "files")
  Dir.foreach path do |filename|
    next unless filename =~ /(.+)\.json$/
    id = $1

    json_path = File.join(path, filename)
    file = OParl::File.load_from(json_path)
    file.downloadUrl = sprintf(FILE_URI, id)

    pdf_path = File.join(path, "#{id}.pdf")
    unless File.exist? pdf_path
      puts "Fetch file #{id}: #{file.name}"
      begin
        tmp_file = Scrape.download_file(file.downloadUrl)
        FileUtils.mv tmp_file.path, pdf_path

        tmp_file.close
        tmp_file = nil
      ensure
        tmp_file.unlink if tmp_file.is_a? File
      end
    end

    file.mimeType = "application/pdf"
    file.size = File.size(pdf_path)
    if `sha1sum #{pdf_path}` =~ /([0-9a-f]+)/
      file.sha1Checksum = $1
    end
    file.save_to json_path
  end
end

Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList['test/**/*_test.rb']
end
