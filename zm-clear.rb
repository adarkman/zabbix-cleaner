#! /usr/bin/ruby

require 'mysql2'
require 'fileutils'

# Days in Zabbix history to keep
$DAYS_TO_KEEP = 190

# Database access
$DB_USER = "USER_HERE"
$DB_PASSWORD = "PASSWORD_HERE"
$DB_HOST = "MYSQLD_HOST"

# ==== DO NOT TOUCH THIS, unless you REALLY know what you do
$QUERY_LIMIT = 100000
$DOT_PER_QUERY = 1000

$LOCK_FILE = "/var/lock/zm-clear.lock"

def get_time_for_clear (db)
	res = db.query "select UNIX_TIMESTAMP(NOW())-(#{$DAYS_TO_KEEP} * 24 * 60 * 60) as utime"
	return res.first["utime"]
end

def show_date db, unixtime
	res = db.query "select FROM_UNIXTIME(#{unixtime}) as date"
	puts "Deleting before: #{res.first["date"]}"
end

def clear_table (db, table)
	keep_time = get_time_for_clear db
	puts "Unixtime: #{keep_time}"
	show_date db, keep_time
	qs = "select itemid,clock from #{table} where clock<#{keep_time} limit #{$QUERY_LIMIT}"
	puts qs
	i = 0
	print 'Deleting: '
	db.query "begin"
	db.query(qs).each do |row|
		dq = "delete from #{table} where itemid=#{row["itemid"]} and clock=#{row["clock"]}"
		#puts dq
		db.query dq
		i += 1
		if i % $DOT_PER_QUERY == 0 then
			db.query "commit"
			db.query "begin"
			print '.'
		end
	end
	db.query "commit"
	puts ' done'
end

if File.file? $LOCK_FILE then
	puts "Locked by #{$LOCK_FILE}, exiting."
	exit 0
else
		FileUtils.touch $LOCK_FILE
end

$DB = Mysql2::Client.new :host=>$DB_HOST, :database=>'zabbix', :username=>$DB_USER, :password=>$DB_PASSWORD

clear_table $DB, "history"
clear_table $DB, "history_uint"
clear_table $DB, "history_str"
clear_table $DB, "history_text"
clear_table $DB, "history_log"

clear_table $DB, "trends"
clear_table $DB, "trends_uint"

$DB.close

FileUtils.rm_f $LOCK_FILE

exit 0

