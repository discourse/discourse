# frozen_string_literal: true

module DiscourseAutomation
  class WorkflowsController < ::Admin::AdminController
    before_action :fetch_workflow, only: %i[update show destroy]

    def index
      workflows = Workflow.all
      serializer = ActiveModel::ArraySerializer.new(
        workflows,
        each_serializer: WorkflowSerializer,
        root: 'workflows'
      )
      render_json_dump(serializer)
    end

    def show
      serializer = WorkflowSerializer.new(@workflow)
      render_json_dump(serializer)
    end

    def update
      @workflow.update!(workflow_params)
      serializer = WorkflowSerializer.new(@workflow)
      render_json_dump(serializer)
    end

    def create
      workflow = Workflow.new(workflow_params)
      workflow.save!
      serializer = WorkflowSerializer.new(workflow)
      render_json_dump(serializer)
    end

    def destroy
      @workflow.destroy
      render json: success_json
    end

    private

    def workflow_params
      params.require(:workflow).permit(:name)
    end

    def fetch_workflow
      @workflow = Workflow.find(params[:id])
    end
  end
end
