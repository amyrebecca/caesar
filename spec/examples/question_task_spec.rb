require 'json'
require 'rails_helper'

class TestProxy
  def initialize(contents)
    @contents = contents
  end

  def data
    @contents
  end

  def reducer_id
    "votes"
  end
end

describe 'Question Tasks' do
  let(:json_data) do
    File.read(Rails.root.join('spec/fixtures/question_task.json'))
  end

  let(:event_hash) do
    JSON.parse(json_data).with_indifferent_access
  end

  let(:kinesis_event) do
    StreamEvents::ClassificationEvent.new(event_hash)
  end

  let(:classification) do
    Classification.new(event_hash["data"])
  end

  let(:workflow_id) do
    event_hash.fetch("data").fetch("links").fetch("workflow")
  end

  let(:nero_config) do
    event_hash[:linked][:workflows][0][:nero_config]
  end

  let(:extractors) do
    nero_config[:extractors]
  end

  let(:reducers) do
    nero_config[:reducers]
  end

  let(:rules) do
    nero_config[:rules]
  end

  let(:workflow) do
    Workflow.create extractors_config: extractors,
                    reducers_config: reducers,
                    rules_config: rules
  end

  let(:pipeline) do
    workflow.classification_pipeline
  end

  let(:subject) { Subject.create }

  it 'should know that Caesar is enabled for this workflow' do
    expect(kinesis_event.send(:enabled?)).to be(true)
  end

  it 'initializes from the example in a sane way' do
    expect(classification).not_to be(nil)
    expect(kinesis_event).not_to be(nil)
    expect(nero_config).not_to be(nil)
    expect(workflow).not_to be(nil)
    expect(pipeline).not_to be(nil)
  end

  it 'extracts the classification as expected' do
    extracts = pipeline.extractors["votes"].process(classification)
    expect(extracts).to include("value")
    expect(extracts).not_to include("votes")
    expect(extracts["value"]).to be == "0"
  end

  it 'reduces the classifications as expected' do
    extract = pipeline.extractors["votes"].process(classification)
    reducer = pipeline.reducers["votes"]
    reduction = reducer.reduction_data_for([TestProxy.new(extract)])

    expect(reduction).to include("0")
    expect(reduction).not_to include("1")
    expect(reduction["0"]).to be == 1
  end

  it 'applies the rules to the extracts' do
    extract = pipeline.extractors["votes"].process(classification)
    reducer = pipeline.reducers["votes"]
    reduction = reducer.reduction_data_for([TestProxy.new(extract)])

    rule_bindings = RuleBindings.new([TestProxy.new(reduction)])
    pipeline.rules.process(workflow_id, 6708469, rule_bindings)
  end
end
