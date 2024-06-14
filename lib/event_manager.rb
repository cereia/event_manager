# frozen_string_literal: true

require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'time'
require 'date'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_phone_number(homephone)
  homephone.gsub!(/\D/, '')
  if homephone.length == 10
    homephone
  elsif homephone.length == 11 && homephone[0] == '1'
    homephone[1..10]
  end
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representative by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

puts 'EventManager initialized.'

def attendees_csv
  CSV.open(
    'event_attendees.csv',
    headers: true,
    header_converters: :symbol
  )
end

def most_frequent_registration_hour
  registration_hours = []
  contents = attendees_csv
  contents.each do |row|
    regdate = row[:regdate]
    registration_hours << Time.strptime(regdate, '%M/%d/%Y %k:%M').hour
  end
  registration_frequencies(registration_hours)
end

def most_frequent_registration_day_of_the_week
  registration_days_of_the_week = []
  contents = attendees_csv
  contents.each do |row|
    regdate = row[:regdate]
    registration_days_of_the_week << Date.strptime(regdate, '%M/%d/%Y %k:%M').wday
  end
  registration_frequencies(registration_days_of_the_week)
end

def registration_frequencies(reg_arr)
  hash = {}
  reg_arr.each_with_object(Hash.new(0)) do |value, result|
    result[value] += 1
    hash = result
  end
  hash.max_by { |_key, value| value }
end

def clean_phone_numbers
  cleaned_numbers = []
  contents = attendees_csv
  contents.each do |row|
    homephone = clean_phone_number(row[:homephone])
    cleaned_numbers << homephone
  end
  cleaned_numbers
end

def create_thank_you_letters
  template_letter = File.read('form_letter.erb')
  erb_template = ERB.new template_letter
  contents = attendees_csv
  contents.each do |row|
    id = row[0]
    name = row[:first_name]
    zipcode = clean_zipcode(row[:zipcode])
    legislators = legislators_by_zipcode(zipcode)
    form_letter = erb_template.result(binding)
    # homephone = clean_phone_number(row[:homephone])
    save_thank_you_letter(id, form_letter)
  end
end

# puts create_thank_you_letters
clean_phone_numbers.map { |num| puts num}
puts "The most frequent registration hour(s): #{most_frequent_registration_hour}"
puts "The most frequent registration day(s) of the week: #{most_frequent_registration_day_of_the_week}"
