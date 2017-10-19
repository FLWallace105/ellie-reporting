require 'sinatra/base'
require 'json'
require 'httparty'
require 'dotenv'
require 'resque'
require 'pg'
require 'logger'
#require 'active_support/core_ext'
require 'sinatra/activerecord'
require 'sinatra/support'
require "sinatra/basic_auth"


require './models/model'
#require './helpers/submetrics_helpers'

class EllieActive < Sinatra::Base
    
        #helpers Sinatra::MySubMetric::SubMetricsUtils
    
        register Sinatra::ActiveRecordExtension
        register Sinatra::Numeric
        register Sinatra::BasicAuth
    
    configure do
        enable :logging
        set :server, :puma
        #set :environment, :production
        #set  :show_exceptions
        Dotenv.load
        $logger = Logger.new('logs/common.log','weekly')
        $logger.level = Logger::INFO
        #set :protection
        #set :database, {adapter: "mysql2", database: "submetrics"}
        #ENV variables here, REDIS
        #set :database, {adapter: "mysql2", database: "submetrics"}
    
    end
    
    
    def initialize
        #some instance variable
        @ellie_3pack_id = ENV['ELLIE_THREE_PACK_ID']
        @monthly_box_id = ENV['MONTHLY_BOX_ID']
        @three_months_id = ENV['THREE_MONTHS_ID']
        @user_name = ENV['USER_NAME']
        @password = ENV['PASSWORD']
        super
    end
    
    # Specify your authorization logic
    authorize do |username, password|
        username == 'famadmin' && password == 'hoser'
    end
  
    # Set protected routes
    protect do
        get "/admin" do
        "Restricted page that only admin can access"
        end
    end
    
    
    protect do
        get '/reporting' do
      
            #status 200
            my_today = Date.today
            my_last_month = my_today << 1
            #puts my_last_month.inspect
            my_end_last_month = my_last_month.end_of_month
            #puts my_end_last_month.inspect
            my_partial_start = my_end_last_month.strftime("%Y-%m-%d 23:59:59")
            #puts my_partial_start.inspect
            my_end = Date.today - 1
            my_end_date = my_end.strftime("%Y-%m-%d")
            my_yesterday_date = my_end.strftime("%Y-%m-%d 23:59:59")
            #puts my_end_date.inspect

            @new_subs_this_month = Subscription.where("shopify_product_id = ? and created_at > ? and created_at <? and status=?", @monthly_box_id, my_partial_start, my_end_date, 'ACTIVE').count(:id)
            @new_threepack_subs_this_month = Subscription.where("shopify_product_id = ? and created_at > ? and created_at <? and status=?", @ellie_3pack_id, my_partial_start, my_end_date, 'ACTIVE').count(:id)
            @new_three_months_subs_this_month = Subscription.where("shopify_product_id = ? and created_at > ? and created_at <? and status=?", @three_months_id, my_partial_start, my_end_date, 'ACTIVE').count(:id)
            @canceled_monthly_box_this_month = Subscription.where("shopify_product_id = ? and created_at > ? and created_at <? and status=?", @monthly_box_id, my_partial_start, my_end_date, 'CANCELLED').count(:id)
            @canceled_threepack_this_month = Subscription.where("shopify_product_id = ? and created_at > ? and created_at <? and status=?", @ellie_3pack_id, my_partial_start, my_end_date, 'CANCELLED').count(:id)
            @canceled_threemonths_this_month = Subscription.where("shopify_product_id = ? and created_at > ? and created_at <? and status=?", @three_months_id, my_partial_start, my_end_date, 'CANCELLED').count(:id)
            @new_monthly_sub_yesterday = Subscription.where("shopify_product_id = ? and created_at > ?  and status=?", @monthly_box_id, my_yesterday_date, 'ACTIVE').count(:id)
            @new_threepack_sub_yesterday = Subscription.where("shopify_product_id = ? and created_at > ?  and status=?", @ellie_3pack_id, my_yesterday_date, 'ACTIVE').count(:id)
            @new_three_months_sub_yesterday = Subscription.where("shopify_product_id = ? and created_at > ?  and status=?", @three_months_id, my_yesterday_date, 'ACTIVE').count(:id)
            @monthly_box_all_time_active = Subscription.where("shopify_product_id = ?  and status=?", @monthly_box_id,  'ACTIVE').count(:id)
            @monthly_box_all_time_cancelled = Subscription.where("shopify_product_id = ?  and status=?", @monthly_box_id,  'CANCELLED').count(:id)
            @ellie_three_all_time_active = Subscription.where("shopify_product_id = ?  and status=?", @ellie_3pack_id,  'ACTIVE').count(:id)
            @ellie_three_all_time_cancelled = Subscription.where("shopify_product_id = ?  and status=?", @ellie_3pack_id,  'CANCELLED').count(:id)
            @three_months_all_time_active = Subscription.where("shopify_product_id = ?  and status=?", @three_months_id,  'ACTIVE').count(:id)
             @three_months_all_time_cancelled = Subscription.where("shopify_product_id = ?  and status=?", @three_months_id,  'CANCELLED').count(:id)
            #get placeholders for begin_next_month, current_month_end, begin_current_month
            next_month = Date.today
            next_month = next_month >> 1
            next_month = next_month.beginning_of_month
            begin_next_month = next_month.strftime("%Y-%m-%d")
            begin_current = Date.today
            begin_current = begin_current.beginning_of_month
            begin_current_month = begin_current.strftime("%Y-%m-%d")
            current_month_end = Date.today
            current_month_end = current_month_end.end_of_month
            current_month_end_str = current_month_end.strftime("%Y-%m-%d")

            my_monthly_box_skip = "select count(customer_id) as num_skips from subscriptions where next_charge_scheduled_at > \'#{current_month_end_str}\' and created_at < \'#{begin_current_month}\' and shopify_product_id = \'#{@monthly_box_id}\' and customer_id not in (select customer_id from charges where scheduled_at > \'#{my_partial_start}\' and scheduled_at < \'#{begin_next_month}\' and line_items->0->>'title' = 'Monthly Box')"
            @my_skip_monthly = ActiveRecord::Base.connection.execute(my_monthly_box_skip)
            #@puts @my_skip_monthly.inspect
            @my_monthly_skip_num = ""
            @my_skip_monthly.each do |row|
                @my_monthly_skip_num = row['num_skips']
            end
            puts @my_monthly_skip_num

            my_ellie_three_box_skip = "select count(customer_id) as num_skips from subscriptions where next_charge_scheduled_at > \'#{current_month_end_str}\' and created_at < \'#{begin_current_month}\' and shopify_product_id = \'#{@ellie_3pack_id}\' and customer_id not in (select customer_id from charges where scheduled_at > \'#{my_partial_start}\' and scheduled_at < \'#{begin_next_month}\' and line_items->0->>'title' = 'Ellie 3- Pack')"
            @my_skip_threepack = ActiveRecord::Base.connection.execute(my_ellie_three_box_skip)
            #@puts @my_skip_monthly.inspect
            @my_threepack_skip_num = ""
            @my_skip_threepack.each do |row|
                @my_threepack_skip_num = row['num_skips']
            end
            puts @my_threepack_skip_num

            my_three_months_skip = "select count(customer_id) as num_skips from subscriptions where next_charge_scheduled_at > \'#{current_month_end_str}\' and created_at < \'#{begin_current_month}\' and shopify_product_id = \'#{@three_months_id}\' and customer_id not in (select customer_id from charges where scheduled_at > \'#{my_partial_start}\' and scheduled_at < \'#{begin_next_month}\' and line_items->0->>'title' = '3 MONTHS')"
            @my_skip_three_months = ActiveRecord::Base.connection.execute(my_three_months_skip)
            #@puts @my_skip_monthly.inspect
            @my_threemonths_skip_num = ""
            @my_skip_three_months.each do |row|
                @my_threemonths_skip_num = row['num_skips']
            end
            puts @my_threemonths_skip_num
            erb :reporting_view
        end
    end
    
    get '/hello' do
        status 200
        "Hi there!"
    end
    
    
    end