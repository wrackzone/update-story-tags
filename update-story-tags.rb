require 'rally_api'
require 'logger'
require 'csv'

class UpdateStoryTags

	# def initialize(workspace,project)
	def	initialize(url,username,password,workspace_name,file_name,log_file)

		@log = Logger.new( log_file , 'daily' )

		@headers = RallyAPI::CustomHttpHeader.new()
		@headers.name = "LookBackData"
		@headers.vendor = "Rally"
		@headers.version = "1.0"

		@config = {:base_url => url} # "https://rally1.rallydev.com/slm"}
		@config[:username]   = username 
		@config[:password]   = password
		@config[:workspace]  = workspace_name
		@config[:version]    = "1.40"
# 		@config[:project]    = @project_name
		@config[:headers]    = @headers #from RallyAPI::CustomHttpHeader.new()

		@rally = RallyAPI::RallyRestJson.new(@config)

		@workspace = find_object(:workspace,workspace_name)
		@log.debug(@workspace)
		@username = username
		@password = password
		@file_name = file_name

	end
	
	def find_object(type,name)
		object_query = RallyAPI::RallyQuery.new()
		object_query.type = type
		object_query.fetch = "Name,ObjectID,FormattedID,Parent"
		object_query.project_scope_up = false
		object_query.project_scope_down = true
		object_query.order = "Name Asc"
		object_query.query_string = "(Name = \"" + name + "\")"
		results = @rally.find(object_query)
		results.each do |obj|
			return obj if (obj.Name.eql?(name))
		end
		nil
	end
	
	def find_object_by_id(type,id)
		object_query = RallyAPI::RallyQuery.new()
		object_query.type = type
		object_query.fetch = "Name,ObjectID,FormattedID,Parent,Tags"
		object_query.project_scope_up = false
		object_query.project_scope_down = true
		object_query.order = "Name Asc"
		object_query.query_string = "(FormattedID = \"" + id + "\")"
		results = @rally.find(object_query)
		results.each do |obj|
			return obj if (obj.FormattedID.eql?(id))
		end
		nil
	end
	
	def update_tags
	    print "reading csv file...\n"
        input = CSV.read(@file_name)
        header = input.first #header row
        rows = []
        (1...input.size).each { |i| rows << CSV::Row.new(header, input[i]) }
        rows.each { |row| 
            newtag = row["New Tag"]
            id = row["Formatted ID"] 
            update_story(id,newtag) if newtag && newtag.length > 0
        }
	end
	
	def update_story(id,tag)
	    print id,":",tag,"\n"
	    story = find_object_by_id(:hierarchicalrequirement,id)
	    if !story
	        print id," not found!\n"
	    else
	        print story.FormattedID,"\n"
	        tag_strings = tag.split(";")
	        tag_strings.delete_if { |e| !e || e==""}
	        tags = []
	        
	        tag_strings.each { | tag_string |
	            print "looking for tag '#{tag_string}'\n"
	            tagobj = find_object(:tag,tag_string)
	            tags.push(tagobj) if tag
	        }
	        print "updating with #{tags.length()} tags\n"
	        @rally.update("story","FormattedID|#{story["FormattedID"]}",{:tags => tags})
	        print "Updated:#{story.FormattedID}\n"
	        @log.debug("#{story.FormattedID}")

	    end
	    
	end
	
end



def validate_args args

	#pp args

	if args.size != 2
		false
	else
		config = JSON.parse(File.read(ARGV[0]))
		config["password"] = args[1]
		config
	end

end

config = validate_args(ARGV)

if  !config
	print "use: ruby update-story-tags.rb config.json <password>\n"
	exit
end

url            = config["url"]
username       = config["username"]
password       = config["password"]
workspace_name = config["workspace_name"]
file_name   = config["file_name"]

ust = UpdateStoryTags.new(url,username,password,workspace_name,file_name,"log.txt")

ust.update_tags

