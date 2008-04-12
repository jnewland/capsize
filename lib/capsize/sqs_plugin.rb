module Capsize
  module CapsizeSQS
    include Capsize

    #Creqte the XML for our CapQueue messages
    def build_xml
      body = ""
      xml = Builder::XmlMarkup.new(:target => body, :indent => 2)
      xml.command do
        xml.hosts do
          get(:hosts).split(/,/).each do |host|
            xml.host host
          end unless get(:hosts).nil?
        end
        xml.environment do
          get(:environment).split(/,/).each do |keyvar|
            xml.variable do
              key, var = keyvar.split(/=/,2)
              var.gsub!(/("|')/,'')
              xml.key key
              xml.var var
            end
          end unless get(:environment).nil?
        end
        xml.variables do
          get(:variables).split(/,/).each do |keyvar|
            xml.variable do
              key, var = keyvar.split(/=/,2)
              var.gsub!(/("|')/,'')
              xml.key key
              xml.var var
            end
          end unless get(:variables).nil?
        end
        xml.task get(:task)
      end
      body
    end

    #returns an instance of SQS::Queue
    def connect
      set :aws_access_key_id, get(:aws_access_key_id)
      set :aws_secret_access_key, get(:aws_secret_access_key)

      raise Exception, "You must have an :aws_access_key_id defined in your config." if fetch(:aws_access_key_id).nil? || fetch(:aws_access_key_id).empty?
      raise Exception, "You must have an :aws_secret_access_key defined in your config." if fetch(:aws_secret_access_key).nil? || fetch(:aws_secret_access_key).empty?

      SQS.access_key_id = fetch(:aws_access_key_id)
      SQS.secret_access_key = fetch(:aws_secret_access_key)

      queue = nil
      begin
        queue = SQS.get_queue queue_name
      rescue
        queue = SQS.create_queue queue_name
      ensure
        return queue
      end
    end

    def delete( options=nil )
      queue = connect()
      queue.delete(options)
    end

    def delete!
      queue = connect()
      queue.delete!
    end

    def send_message( m )
      queue = connect()
      queue.send_message(m)
    end

    def get_queue_attributes( force=false )
      queue = connect()
      queue.get_queue_attributes(force)
    end

    def set_queue_attributes( atts={} )
      queue = connect()
      queue.set_queue_attributes(atts)
    end

    def empty?
      queue = connect()
      queue.empty?
    end

    def peek_message
      queue = connect()
      queue.peek_message
    end

    def peek_messages( options={} )
      queue = connect()
      queue.peek_messages(options)
    end

    def receive_message
      queue = connect()
      queue.receive_message
    end

    def receive_messages( options={} )
      queue = connect()
      queue.receive_messages(options)
    end

    def add_grant( options={} )
      queue = connect()
      queue.add_grant(options)
    end

    def remove_grant( options={} )
      queue = connect()
      queue.remove_grant(options)
    end

    def list_grants
      queue = connect()
      queue.list_grants
    end

  end
end
Capistrano.plugin :capsize_sqs, Capsize::CapsizeSQS