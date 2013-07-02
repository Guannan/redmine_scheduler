class TimesheetsController < ApplicationController
  unloadable
  load_and_authorize_resource

  before_filter :wage_check, :except => [:approve,:delete,:reject]

  def index
    if params[:user]
      @user = User.find(params[:user])
      @timesheets = @timesheets.for_user(@user)
    end

    @submitted = @timesheets.is_submitted.is_not_approved.page(params[:submitted_page])
    @approved = @timesheets.is_submitted.is_approved.page(params[:approved_page])
    @rejected = @timesheets.rejected.page(params[:rejected_page])

    respond_to do |format|
      format.html
      format.js
    end
  end

  def new
    @timesheet = Timesheet.new

    if params[:user]
      @user = User.find(params[:user])
    else
      if User.current.is_admstaff?
        @user = Group.stustaff.first.users.first
      else
        @user = User.current
      end
    end

    params[:weekof] ? @weekof = Date.parse(params[:weekof]) : @weekof = Date.today.beginning_of_week

    @time_entries = @user.time_entries.on_week(@weekof).not_on_timesheet

    @previous_sheets = @user.timesheets.weekof_on(@weekof)

    @shifts = Issue.shifts.from_date(@weekof).until_date(@weekof + 6.days)
    @fd_shifts = @shifts.fdshift
    @lc_shifts = @shifts.lcshift.foruser(@user)

    respond_to do |format|
      format.html
      format.js
    end
  end

  def create
    @timesheet = Timesheet.new(params[:timesheet])
    @timesheet.user = User.find(params[:user])
    @timesheet.weekof = Date.parse(params[:weekof])
    @timesheet.commit_time_entries

    if @timesheet.save
      flash[:notice] = 'Timesheet submitted. Please print it out and submit it to the manager.'
      redirect_to @timesheet
    else
      flash[:warning] = "Timesheet could not be saved: #{@timesheet.errors.full_messages}"
      redirect_to action: 'new', user: @user, weekof: @timesheet.weekof
    end
  end

  def show

    if @timesheet.time_entries.empty?
      @time_entries = @timesheet.user.time_entries.on_week(@timesheet.weekof)
    else
      @time_entries = @timesheet.time_entries
    end

    @weekof = @timesheet.weekof

    respond_to do |format|
      format.html
      format.pdf { render :layout => false }
    end
  end

  def print
    if @timesheet.print_now && @timesheet.save
      redirect_to action: :show, format: :pdf, id: @timesheet
    else
      flash[:warning] = 'Could not print timesheet. I need some better error handling'
      redirect_to :action => 'index'
    end
  end

  def edit
    @user = @timesheet.user

    @weekof = @timesheet.weekof

    @time_entries = @user.time_entries.on_week(@weekof).not_on_timesheet

    @previous_sheets = []

    @shifts = Issue.shifts.from_date(@weekof).until_date(@weekof + 6.days)
    @fd_shifts = @shifts.fdshift
    @lc_shifts = @shifts.lcshift.foruser(@user)

    respond_to do |format|
      format.html
      #format.js
    end
  end

  def update
    @timesheet.commit_time_entries
    @timesheet.submit_now

    if @timesheet.update_attributes(params[:timesheet])
      flash[:notice] = "Timesheet for #{@timesheet.user.name} for the week starting on #{@timesheet.weekof} was successfully resubmitted."
      redirect_to @timesheet
    else
      flash[:warning] = "Could not save. Errors: " + timesheet.errors.full_messages.join(", ")
      redirect_to edit_timesheet_path(@timesheet)
    end
  end

  def submit
    if @timesheet.submit_now && @timesheet.save
      flash[:notice] = "Timesheet for #{@timesheet.user.name} for the week starting on #{@timesheet.weekof} was successfully submitted."
      redirect_to :action => 'index'
    else
      flash[:warning] = "Could not save. Errors: " + timesheet.errors.full_messages.join(", ")
      redirect_to :action => 'index'
    end
  end

  def approve
    @timesheet.approve_now

    if @timesheet.save
      flash[:notice] = "Timesheet for #{@timesheet.user.name} for the week starting on #{@timesheet.weekof} was successfully approved."
      redirect_to :action => 'index'
    else
      flash[:warning] = "Could not save. Errors: " + timesheet.errors.full_messages.join(", ")
      redirect_to :action => 'index'
    end
  end

  def delete
    @timesheet.destroy

    if @timesheet.save
      flash[:notice] = "Timesheet has been successfully deleted!"
      redirect_to :action => 'index'
    else
      flash[:warning] = "An error occurred when deleting the timesheet.."
      redirect_to :action => 'index'
    end
  end

  def reject
    @timesheet.reject_now

    if @timesheet.save
      flash[:notice] = "Timesheet successfully rejected"
      redirect_to :action => 'index'
    else
      flash[:notice] = "An error occurred when rejecting timesheet"
      redirect_to :action => 'index'
    end
  end

  private

  def wage_check
    unless User.current.is_admstaff?
      session[:return_to] = request.referer
      if User.current.wage.nil?
        flash[:warning] = "You don't seem to be assigned a wage. Please speak to your manager."
        redirect_to session[:return_to]
        #redirect_to :action => 'index'  #works well with all actions except when triggered going into timesheet index
      end
    end
  end

  def find_user
    if params[:timesheet].present?
      @user = User.find(params[:timesheet][:user_id])
    elsif params[:user].present?
      @user = User.find(params[:user].to_i)
    else
      @user = User.current
    end
  end

  def find_first_monday(year)
    t = Date.new(year, 1,1).wday     #checks which day (Mon = 1, Sun = 0) is first day of the year 
    if t == 0
      return Date.new(year, 1,2)
    elsif t == 1
      return Date.new(year, 1,1)
    else
      return Date.new(year, 1,(1+8-t))     #cases designed to return the first Monday of the year's date
    end
  end

  def validate_existence(user,weekof)
    existing = Timesheet.for_user(user).weekof_on(weekof)
    if !existing.empty?
      flash.now[:warning] = "There is already a timesheet for the selected week. Please select another."
    end
  end

  def find_entries_by_day(weekof)
    if @timesheet.id != nil
      @entries_by_day = @timesheet.entries_for_week.group_by(&:spent_on)
    else
      @entries = TimeEntry.foruser(@user).from_date(weekof).until_date(weekof + 1.week).sort_by_date
      @entries_by_day = @entries.group_by(&:spent_on)  
    end
  end

  def dates(to,from)
    dates = []
    date = to
    while date >= from do
      dates << [date.strftime("Week of %B %d, Year %Y"), date.to_s]
      date -= 7.day
    end
    return dates
  end

  #retrieving information from selection
  def find_selection_week_year
    if params[:week_sel].present?
      w = Date.parse(params[:week_sel])
      @cweek = w.cweek
      @year_selected = w.year
    else
      @cweek = Date.today.cweek
      @year_selected = Date.today.year
    end
  end

  #I know this is more or less redundant from method above
  def find_selection_week
    if params[:weekof].present?
      @weekof = Date.parse(params[:weekof])
    else
      flash[:notice] = "You must specify a pay period."
      redirect_to :action => 'new'
    end
  end

  def find_shifts_by_day(weekof)
    issues = Issue.from_date(weekof).until_date(weekof + 1.week)
    fdshifts = issues.fdshift
    lcshifts = issues.lcshift
    
    @shifts_by_day = (fdshifts+lcshifts).group_by(&:start_date)
  end

  def get_goals(user)
    @goals = Issue.foruser(user).goals
  end

  def get_tasks(user)
    @tasks = Issue.foruser(user).tasks
  end
end
