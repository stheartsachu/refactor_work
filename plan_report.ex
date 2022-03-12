defmodule Planning.PlanReport do
  alias Planning.Services.{
    PlanReportQueries,
    PlanQueries,
    MeasureQueries,
    AccountManagementQueries,
    OutcomeSetQueries,
    InstitutionDataQueries,
    ClientManagementQueries,
    StrategicPlanQueries
  }

  alias Planning.{Plan, Measure}
  alias Planning.Schema.{Organization, Course}

  @program_assessment_type 0
  @course_assessment_type 1
  @outcome_not_met 0
  @outcome_met 1
  @program_plan "program"
  @course_plan "course"
  @student_counts "StudentCounts"
  @student_scores "StudentScores"
  @file_upload "FileUpload"
  @external_reports "ExternalReports"
  @learning "Learning"
  @success "NonLearning"
  @canvas "canvas"
  @blackboard "blackboard"
  @desire2learn "desire2learn"
  @overall_score "OverallScore"

  @doc """
    Get org detail for a particular program plan

    ## Parameters
      - plan_uuid - Unique identifier of plan
      - org_uuid - Unique identifier of organization
  """
  def export_program_plan_html_report(plan_uuid, org_uuid, institution_uuid) do
    %Organization{uuid: org_uuid, name: org_name} =
      InstitutionDataQueries.get_organization(org_uuid)

    plan = PlanQueries.get_plan(plan_uuid)

    plan_outcome_data =
      PlanReportQueries.get_program_plan_outcome_data_by_org(plan_uuid, org_uuid)

    learning_outcomes_data =
      Enum.filter(plan_outcome_data, &(&1.outcome_type == @learning))
      |> get_plan_outcomes_data(plan_uuid, org_uuid)
      |> Enum.map(fn plan_outcome ->
        outcome_details =
          Planning.Measure.get_current_revision_outcome_details(plan_outcome.outcome_uuid, plan)

        plan_outcome
        |> Map.drop([
          :description,
          :outcome_set_name,
          :outcome_name,
          :outcome_type,
          :outcome_uuid,
          :sort_order,
          :is_archived
        ])
        |> Map.merge(%{
          description: outcome_details.description,
          outcome_set_name: outcome_details.organization_outcome_set_name,
          outcome_name: outcome_details.title,
          outcome_type: outcome_details.type,
          outcome_uuid: outcome_details.parent_outcome || outcome_details.uuid,
          sort_order: outcome_details.sort_order,
          is_archived: outcome_details.is_archived
        })
      end)
      |> sort_outcomes_based_on_sort_order()

    success_oucomes_data =
      Enum.filter(plan_outcome_data, &(&1.outcome_type == @success))
      |> get_plan_outcomes_data(plan_uuid, org_uuid)
      |> Enum.map(fn plan_outcome ->
        outcome_details =
          Planning.Measure.get_current_revision_outcome_details(plan_outcome.outcome_uuid, plan)

        plan_outcome
        |> Map.drop([
          :description,
          :outcome_set_name,
          :outcome_name,
          :outcome_type,
          :outcome_uuid,
          :sort_order,
          :is_archived
        ])
        |> Map.merge(%{
          description: outcome_details.description,
          outcome_set_name: outcome_details.organization_outcome_set_name,
          outcome_name: outcome_details.title,
          outcome_type: outcome_details.type,
          outcome_uuid: outcome_details.parent_outcome || outcome_details.uuid,
          sort_order: outcome_details.sort_order,
          is_archived: outcome_details.is_archived
        })
      end)
      |> sort_outcomes_based_on_sort_order()

    plan_info = PlanQueries.get_plan_and_reporting_year_name(plan_uuid)

    mission_statement = get_mission_statement_for_reporting_year(org_uuid, plan_info)

    {:ok, count_categories_nomenclature} =
      Measure.get_count_categories_nomenclature(institution_uuid)

    budget_currency_code =
      institution_uuid
      |> PlanQueries.get_budget_request_with_currency_code()
      |> get_budget_currency_code()

    org_data = %{
      org_uuid: org_uuid,
      org_name: org_name,
      mission_statement: mission_statement,
      learning_outcomes: learning_outcomes_data,
      success_outcomes: success_oucomes_data
    }

    %{
      plan_info: plan_info,
      org_data: org_data,
      budget_currency_code: budget_currency_code,
      count_categories_nomenclature: count_categories_nomenclature
    }
  end

  @doc """
    Get Outcome Detail for plan outcome
    ## Parameters
      plan_outcome_uuid : Unique Identifier for Plan Outcome
      institution_uuid: Unique Identifier for Institution
  """

  def export_plan_outcome_html_report(plan_outcome_uuid, institution_uuid) do
    plan_outcome = PlanReportQueries.get_plan_outcome_detail(plan_outcome_uuid)
    plan = PlanQueries.get_plan(plan_outcome.plan_uuid)

    outcome_revision =
      Planning.Measure.get_current_revision_outcome_details(plan_outcome.outcome_uuid, plan)

    {:ok, count_categories_nomenclature} =
      Measure.get_count_categories_nomenclature(institution_uuid)

    budget_currency_code =
      institution_uuid
      |> PlanQueries.get_budget_request_with_currency_code()
      |> get_budget_currency_code()

    revised_plan_outcome =
      plan_outcome
      |> Map.merge(%{
        description: outcome_revision.description,
        outcome_title: outcome_revision.title,
        outcome_uuid: outcome_revision.parent_outcome || outcome_revision.uuid,
        sort_order: outcome_revision.sort_order,
        is_archived: outcome_revision.is_archived
      })

    revised_plan_outcome
    |> get_plan_outcome_data(plan_outcome.plan_uuid, plan_outcome.org_uuid)
    |> Map.merge(revised_plan_outcome)
    |> Map.merge(%{
      budget_currency_code: budget_currency_code,
      count_categories_nomenclature: count_categories_nomenclature
    })
    |> Map.drop([:plan_uuid])
  end

  @doc """
    Get org detail for a particular course plan
    ## Parameters
      - plan_uuid - Unique identifier of plan
      - course_uuid - Unique identifier of course
  """

  def export_course_plan_html_report(plan_uuid, course_uuid, institution_uuid) do
    %Course{} = course_data = PlanReportQueries.get_course_by_uuid(course_uuid)
    plan = PlanQueries.get_plan(plan_uuid)

    plan_outcome_data =
      PlanReportQueries.get_course_plan_outcomes(plan_uuid, course_uuid)
      |> Enum.map(fn plan_outcome ->
        outcome_details =
          Planning.Measure.get_current_revision_outcome_details(plan_outcome.outcome_uuid, plan)

        plan_outcome
        |> Map.drop([
          :description,
          :outcome_set_name,
          :outcome_name,
          :outcome_title,
          :outcome_uuid,
          :sort_order,
          :is_archived
        ])
        |> Map.merge(%{
          description: outcome_details.description,
          outcome_set_name: outcome_details.course_outcome_set_name,
          outcome_name: outcome_details.title,
          outcome_title: outcome_details.title,
          outcome_uuid: outcome_details.parent_outcome || outcome_details.uuid,
          sort_order: outcome_details.sort_order,
          is_archived: outcome_details.is_archived
        })
      end)
      |> sort_outcomes_based_on_sort_order()

    budget_currency_code =
      institution_uuid
      |> PlanQueries.get_budget_request_with_currency_code()
      |> get_budget_currency_code()

    outcomes_data = get_plan_outcomes_data(plan_outcome_data, plan_uuid, course_uuid)
    plan_info = PlanQueries.get_plan_and_reporting_year_name(plan_uuid)

    {:ok, count_categories_nomenclature} =
      Measure.get_count_categories_nomenclature(institution_uuid)

    course_data = %{
      course_uuid: course_data.uuid,
      course_name: course_data.catalog_code <> ": " <> course_data.name,
      outcomes: outcomes_data
    }

    %{
      plan_info: plan_info,
      course_data: course_data,
      budget_currency_code: budget_currency_code,
      count_categories_nomenclature: count_categories_nomenclature
    }
  end

  defp get_measurement_results(data_collection_method, plan_outcome_measure_uuid) do
    case data_collection_method do
      @student_counts ->
        PlanReportQueries.get_measure_student_counts_data(plan_outcome_measure_uuid)
        |> convert_list_to_map
        |> Map.merge(get_measure_student_counts_result_files(plan_outcome_measure_uuid))

      @student_scores ->
        get_measurement_student_scores(plan_outcome_measure_uuid)

      @file_upload ->
        evidences =
          PlanReportQueries.get_measure_evidences(plan_outcome_measure_uuid)
          |> Enum.filter(fn evidence -> evidence.evidence_type == @file_upload end)

        %{evidences: evidences}

      @external_reports ->
        %{report_state: report_state, source: source} =
          MeasureQueries.get_measurement_external_reports_data(plan_outcome_measure_uuid)

        rubric = MeasureQueries.get_external_report_rubric_data(plan_outcome_measure_uuid)
        assessment_results = get_assessment_results(source, rubric)

        %{rubric_granularity_type: rubric_granularity_type} =
          get_rubric_granularity_type(source, rubric)

        result_files =
          plan_outcome_measure_uuid
          |> PlanReportQueries.get_measure_evidences()
          |> Enum.filter(fn evidence -> evidence.evidence_type == @external_reports end)

        %{
          assessment_results: assessment_results,
          report_state: report_state,
          source: source,
          rubric_granularity_type: rubric_granularity_type,
          result_files: result_files
        }

      _ ->
        %{}
    end
  end

  @doc """
    Gets action details report data for course plan by plan and nodes

    ## Parameters
      - institution_uuid: Uuid identifier of institution
      - plan_uuid: Uuid identifier of plan
      - organization_uuids: list of Uuid identifiers for oeganization
  """
  def get_course_plan_action_detail_report(institution_uuid, plan_uuid, organization_uuids) do
    budget_request_data = get_budget_request_data(institution_uuid)

    with {:ok, report_data} <-
           PlanReportQueries.get_course_plan_action_detail_report(plan_uuid, organization_uuids),
         {:ok, org_leads} <-
           PlanReportQueries.get_assessment_leads_for_organizations(institution_uuid),
         {:ok, course_leads} <-
           PlanReportQueries.get_assessment_leads_for_courses(organization_uuids) do
      %{
        report_data: report_data,
        org_leads: org_leads,
        course_leads: course_leads,
        budget_request_data: budget_request_data
      }
    end
  end

  @doc """
    Gets measure details report data for course plan by plan and nodes

    ## Parameters
      - institution_uuid: Uuid identifier of institution
      - plan_uuid: Uuid identifier of plan
      - organization_uuids: list of Uuid identifiers for oeganization
  """
  def get_course_plan_measure_detail_report(institution_uuid, plan_uuid, organization_uuids) do
    with {:ok, report_data} <-
           PlanReportQueries.get_course_plan_measure_detail_report(
             institution_uuid,
             plan_uuid,
             organization_uuids
           ),
         {:ok, course_leads} <-
           PlanReportQueries.get_assessment_leads_for_courses(organization_uuids) do
      plan = PlanQueries.get_plan(plan_uuid)

      updated_report_data =
        report_data
        |> Enum.map(fn o ->
          outcome =
            case is_nil(o.outcome_uuid) do
              false ->
                Measure.get_current_revision_outcome_details(
                  o.outcome_uuid,
                  plan
                )

              _ ->
                %{}
            end

          Map.put(o, :outcome_title, Map.get(outcome, :title))
          |> Map.put(:outcome_desc, Map.get(outcome, :description))
          |> Map.put(:is_archived, Map.get(outcome, :is_archived))
          |> Map.put(:outcome_tags, Map.get(outcome, :outcome_tags))
        end)

      %{
        report_data: updated_report_data,
        course_leads: course_leads
      }
    end
  end

  @doc """
    Gets outcome details report data for course plan by plan and nodes

    ## Parameters
      - institution_uuid: Uuid identifier of institution
      - plan_uuid: Uuid identifier of plan
      - organization_uuids: list of Uuid identifiers for oeganization
  """
  def get_course_plan_outcome_detail_report(institution_uuid, plan_uuid, organization_uuids) do
    with {:ok, report_data} <-
           PlanReportQueries.get_course_plan_outcome_detail_report(
             institution_uuid,
             plan_uuid,
             organization_uuids
           ),
         {:ok, outcome_revisions} <-
           report_data
           |> get_outcome_uuids_from_report_data()
           |> get_current_outcome_revisions(),
         {:ok, course_leads} <-
           PlanReportQueries.get_assessment_leads_for_courses(organization_uuids),
         {:ok, outcome_measures} <-
           report_data
           |> get_outcome_uuids_from_report_data()
           |> PlanReportQueries.get_plan_outcomes_measures(plan_uuid) do
      %{
        report_data: report_data,
        course_leads: course_leads,
        outcome_revisions: outcome_revisions,
        outcome_measures: outcome_measures
      }
    end
  end

  defp get_current_outcome_revisions({outcome_uuids, reporting_year_uuid, start_date}) do
    outcome_uuids
    |> PlanReportQueries.get_outcome_revisions(reporting_year_uuid)
    |> IO.inspect(label: "case 1")
    |> get_previous_revisions_if_no_current_revision_exists(outcome_uuids, start_date)
    |> IO.inspect(label: "case 2")
  end

  defp get_previous_revisions_if_no_current_revision_exists(
         outcome_versions,
         outcome_uuids,
         start_date
       ) do
    outcome_versions
    |> Enum.map(& &1.parent_outcome)
    |> Enum.uniq()
    |> List.myers_difference(outcome_uuids)
    |> List.foldl([], fn {key, value}, acc ->
      if key == :ins do
        acc ++ value
      else
        acc
      end
    end)
    |> case do
      [] ->
        {:ok, outcome_versions}

      pending_outcomes ->
        {:ok,
         (PlanReportQueries.get_previous_versions_of_outcomes(pending_outcomes, start_date) ++
            outcome_versions)
         |> group_versioned_outcomes}
    end
  end

  defp group_versioned_outcomes([]) do
    []
  end

  defp group_versioned_outcomes(versioned_outcomes) do
    versioned_outcomes
    |> Enum.group_by(fn versioned_outcomes -> versioned_outcomes.parent_outcome end)
    |> Enum.map(fn {_key, outcomes} ->
      outcomes
      |> Enum.sort_by(&(&1.start_date && &1.updated_at), {:desc, NaiveDateTime})
      |> List.first()
    end)
  end

  defp get_outcome_uuids_from_report_data(report_data) do
    {reporting_year_uuid, start_date} =
      case List.first(report_data) do
        nil ->
          {"", ""}

        report ->
          {report.reporting_year_uuid, report.start_date}
      end

    outcome_uuids =
      Enum.map(report_data, fn data ->
        # data.outcome_uuid

        IO.inspect([data.outcome_uuid, data.active_outcome_revision],
          label: "outcome_uuid || active_outcome_revision"
        )

        case data.outcome_uuid == data.active_outcome_revision do
          false ->
            data.active_outcome_revision

          true ->
            data.outcome_uuid
        end
      end)
      |> Enum.uniq()

    IO.inspect(outcome_uuids, label: "outcome_uuids")

    {outcome_uuids, reporting_year_uuid, start_date}
  end

  @doc """
    Gets measure related report data for program plan by plan and organizations

    ## Parameters
      - institution_uuid: Uuid identifier of institution
      - plan_uuid: Uuid identifier of plan
      - organization_uuids: list of Uuid identifiers of organizations
  """
  def get_program_plan_measure_detail_report(institution_uuid, plan_id, organization_uuids) do
    with {:ok, report_data} <-
           PlanReportQueries.get_program_plan_measure_detail_report(plan_id, organization_uuids),
         {:ok, outcome_revisions} <-
           report_data
           |> get_outcome_uuids_from_report_data()
           |> IO.inspect(label: "uuids")
           |> get_current_outcome_revisions(),
         {:ok, org_leads} <-
           PlanReportQueries.get_assessment_leads_for_organizations(institution_uuid) do
      IO.inspect(report_data, label: "report_data")
      IO.inspect(outcome_revisions, label: "outcome_revision")

      measure_terms =
        (PlanReportQueries.get_student_count_terms(
           plan_id,
           organization_uuids
         ) ++
           PlanReportQueries.get_student_score_terms(
             plan_id,
             organization_uuids
           ))
        |> Enum.uniq()
        |> Enum.group_by(& &1.plan_outcome_measure_uuid, & &1.term_name)

      %{
        report_data: report_data,
        outcome_revisions: outcome_revisions,
        org_leads: org_leads,
        measure_terms: measure_terms
      }
    end
  end

  @doc """
    Gets measure result report data for program plan by plan and organizations

    ## Parameters
      - institution_uuid: Uuid identifier of institution
      - plan_uuid: Uuid identifier of plan
      - organization_uuids: list of Uuid identifiers of organizations
  """
  def get_program_plan_measure_result_report(institution_uuid, plan_id, organization_uuids) do
    with {:ok, measure_result} <-
           PlanReportQueries.get_program_plan_measure_result_report(plan_id, organization_uuids),
         {:ok, org_leads} <-
           PlanReportQueries.get_assessment_leads_for_organizations(institution_uuid) do
      grouped_plan_outcome_measure_uuids = Enum.group_by(measure_result, & &1.source)

      outcome_revisions =
        measure_result
        |> get_versioned_outcomes()
        |> elem(1)
        |> Enum.map(fn outcome_revision ->
          {outcome_revision.parent_outcome, outcome_revision}
        end)

      overall_measure_result =
        (Map.get(grouped_plan_outcome_measure_uuids, "desire2learn", []) ++
           Map.get(grouped_plan_outcome_measure_uuids, "canvas", []) ++
           Map.get(grouped_plan_outcome_measure_uuids, "blackboard", []))
        |> Enum.map(& &1.plan_outcome_measure_uuid)
        |> get_overall_result_data()

      updated_criteria_based_measure_result =
        (Map.get(grouped_plan_outcome_measure_uuids, "desire2learn", []) ++
           Map.get(grouped_plan_outcome_measure_uuids, "aqua", []) ++
           Map.get(grouped_plan_outcome_measure_uuids, "via", []))
        |> Enum.map(& &1.plan_outcome_measure_uuid)
        |> get_result_data_for_multiple_criterias()

      internal_measure_result =
        grouped_plan_outcome_measure_uuids
        |> Map.get("internal", [])
        |> Enum.map(& &1.plan_outcome_measure_uuid)
        |> get_internal_results_data()

      measure_result_data =
        (overall_measure_result ++
           internal_measure_result ++ updated_criteria_based_measure_result)
        |> Enum.group_by(& &1.plan_outcome_measure_uuid)
        |> prepare_measure_result_data(measure_result)

      %{
        report_data: measure_result_data,
        org_leads: org_leads,
        versioned_outcomes: outcome_revisions
      }
    end
  end

  @doc """
    Gets action related report data for program plan by plan and organizations

    ## Parameters
    - institution_uuid: Uuid identifier of institution
    - plan_uuid: Uuid identifier of plan
    - organization_uuids: list of Uuid identifiers of organizations
  """
  def get_program_plan_action_detail_report(institution_uuid, plan_id, organization_uuids) do
    budget_request_data = get_budget_request_data(institution_uuid)

    with {:ok, report_data} <-
           PlanReportQueries.get_program_plan_action_detail_report(plan_id, organization_uuids),
         {:ok, outcome_revisions} <-
           report_data
           |> get_outcome_uuids_from_report_data()
           |> get_current_outcome_revisions(),
         {:ok, org_leads} <-
           PlanReportQueries.get_assessment_leads_for_organizations(institution_uuid) do
      %{
        report_data: report_data,
        outcome_revisions: outcome_revisions,
        org_leads: org_leads,
        budget_request_data: budget_request_data
      }
    end
  end

  @doc """
    Gets plan outcomes related report data for program plan by plan and organizations

    ## Parameters
      - plan_uuid: Uuid identifier of plan
      - organization_uuids: list of Uuid identifiers of organization
      - institution_uuid - uuid identifier for institution.
  """
  def get_plan_outcome_detail_report(plan_uuid, organization_uuids, institution_uuid) do
    with {:ok, org_leads} <-
           PlanReportQueries.get_assessment_leads_for_organizations(institution_uuid) do
      report_data =
        PlanReportQueries.get_plan_outcome_detail_report(plan_uuid, organization_uuids)

      {:ok, outcome_revisions} =
        report_data
        |> get_outcome_uuids_from_report_data()
        |> get_current_outcome_revisions()

      %{report_data: report_data, org_leads: org_leads, outcome_revisions: outcome_revisions}
    end
  end

  @doc """
    Gets data for Org Progress Summary Report

    ## Parameters
      - plan_uuid: Uuid identifier of the plan,
      - org_nodes: List of Uuid identifiers of the organization.
      - institution_uuid - uuid identifier for institution.
  """
  def get_plan_organizational_progress_summary_report(plan_id, org_nodes, institution_uuid) do
    with {:ok, org_leads} <-
           PlanReportQueries.get_assessment_leads_for_organizations(institution_uuid) do
      report_data =
        PlanReportQueries.get_plan_organizational_progress_summary_report(plan_id, org_nodes)

      org_leads =
        org_leads
        |> Enum.group_by(& &1.organization_uuid, & &1.user)

      measure_count =
        PlanReportQueries.get_measure_count_for_orgs(plan_id, org_nodes)
        |> convert_list_to_map

      action_count =
        PlanReportQueries.get_action_count_for_orgs(plan_id, org_nodes)
        |> convert_list_to_map

      total_outcomes_count_without_archived_outcomes =
        PlanReportQueries.get_total_outcomes_count_in_plan_by_orgs(plan_id, org_nodes)
        |> convert_list_to_map

      selected_archived_outcomes =
        PlanReportQueries.get_selected_archived_outcomes_count_in_plan_by_orgs(plan_id, org_nodes)
        |> convert_list_to_map

      total_outcomes_count =
        Map.merge(
          total_outcomes_count_without_archived_outcomes,
          selected_archived_outcomes,
          fn _key, outcome_count, selected_archived_outcome_count ->
            outcome_count + selected_archived_outcome_count
          end
        )

      total_plan_outcomes_count =
        PlanReportQueries.get_total_plan_outcomes_count_in_plan_by_orgs(plan_id, org_nodes)
        |> convert_list_to_map

      %{
        report_data: report_data,
        org_leads: org_leads,
        total_plan_outcomes_count: total_plan_outcomes_count,
        measure_count: measure_count,
        total_outcomes_count: total_outcomes_count,
        action_count: action_count
      }
    end
  end

  @doc """
    Gets plan insights data for a single plan for program filter

    ## Parameters
      - institution_uuid: uuid identifier for institution.
      - affiliated_org: affiliated oranization uuid.
      - plan: base plan.
      - selected_node_uuid : Uuid of the selected node.
  """
  def get_plan_insights_data_for_single_plan_for_program_filter(
        institution_uuid,
        affiliated_org,
        plan,
        selected_node_uuid
      ) do
    child_nodes_uuid_list = get_child_nodes_uuid_list(affiliated_org, institution_uuid)
    plan_uuid = plan.plan_uuid

    course_list = PlanQueries.get_courses_for_available_orgs([plan_uuid], child_nodes_uuid_list)

    clo_to_plo_mappings =
      selected_node_uuid
      |> PlanReportQueries.get_clo_to_plo_mappings_by_program(
        course_list,
        institution_uuid
      )

    {clo_plo_data, plan_details} = get_clo_to_plo_mappings_by_program(plan, clo_to_plo_mappings)

    get_single_plan_insights_data_map(plan_uuid, plan_details, institution_uuid, clo_plo_data)
  end

  defp get_single_plan_insights_data_map(plan_uuid, plan_details, institution_uuid, clo_plo_data) do
    # Taking out the first element from the list in case of single plan as the
    # list will contain only one element
    plan_insights_count = hd(get_plan_insights_count([plan_uuid], plan_details))
    plan_measure_type = hd(get_plan_measure_type([plan_uuid], plan_details))
    outcome_status = hd(get_plan_outcome_status([plan_uuid], plan_details))
    measure_status = hd(get_plan_measure_status([plan_uuid], plan_details))
    plan_action_category_count = get_action_count_by_category([plan_uuid], plan_details)
    plan_measure_method_count = get_measure_method_count([plan_uuid], plan_details)

    institution_learning_outcomes =
      get_institution_outcomes_mapping(institution_uuid, plan_uuid, plan_details)

    action_budget_requests =
      hd(get_action_budget_requests_for_plans([plan_uuid], plan_details, institution_uuid))

    %{
      plan_insights_count: plan_insights_count,
      plan_measure_type: plan_measure_type,
      plan_action_category_count: plan_action_category_count,
      plan_measure_method_count: plan_measure_method_count,
      plan_outcome_status: outcome_status,
      plan_measure_status: measure_status,
      institution_learning_outcomes: institution_learning_outcomes,
      action_budget_requests: action_budget_requests,
      clo_to_plo_data: clo_plo_data
    }
  end

  @doc """
    Gets plan insights data for a single plan

    ## Parameters
      - institution_uuid: uuid identifier for institution.
      - plan: base plan.
      - selected_node_uuid : Uuid of the selected node.
      - selected_node_type : Selected node type.
  """

  def get_plan_insights_data_for_single_plan(
        institution_uuid,
        plan,
        selected_node_uuid,
        selected_node_type \\ "none"
      ) do
    plan_uuid = plan.plan_uuid

    {plan_assessment_type, association_uuids} =
      get_plan_details(plan, selected_node_type, selected_node_uuid, institution_uuid)

    clo_plo_data =
      case plan_assessment_type do
        @course_plan ->
          get_clo_to_plo_mappings_for_programs(institution_uuid, plan_uuid, association_uuids)

        _ ->
          []
      end

    plan_details = {plan_assessment_type, association_uuids}

    get_single_plan_insights_data_map(plan_uuid, plan_details, institution_uuid, clo_plo_data)
  end

  defp get_plan_details(plan, selected_node_type, selected_node_uuid, institution_uuid) do
    if plan.assessment_type_id == @course_assessment_type && selected_node_type == "course" do
      {get_plan_assessment_type(plan.assessment_type_id), [selected_node_uuid]}
    else
      child_nodes_uuid_list = get_child_nodes_uuid_list(selected_node_uuid, institution_uuid)

      get_plan_type_and_available_nodes(
        plan.plan_uuid,
        [plan.plan_uuid],
        child_nodes_uuid_list
      )
    end
  end

  @doc """
    Gets plan insights data for comparison for multiple plans when filtering with course

    ## Parameters
      - institution_uuid: uuid identifier for institution.
      - plan_uuids: list of Uuid identifiers of the plans.
      - base_plan_uuid: uuid identifier for the plan to which other plans are being compared
      - selected_node_uuid: node selected for comparison
      - selected_node_type: type of node selected
  """
  def get_plan_insights_data_for_comparison(
        institution_uuid,
        plan_uuids,
        base_plan_uuid,
        selected_node_uuid,
        "course"
      ) do
    plan = PlanQueries.get_plan_info_by_uuid(base_plan_uuid)

    plan_details = {get_plan_assessment_type(plan.assessment_type_id), [selected_node_uuid]}

    get_all_insights_data(plan_uuids, plan_details, base_plan_uuid, institution_uuid)
  end

  def get_plan_insights_data_for_comparison(
        institution_uuid,
        plan_uuids,
        base_plan_uuid,
        selected_node_uuid,
        _selected_node_type
      ) do
    child_nodes_uuid_list = get_child_nodes_uuid_list(selected_node_uuid, institution_uuid)

    plan_details =
      get_plan_type_and_available_nodes(base_plan_uuid, plan_uuids, child_nodes_uuid_list)

    get_all_insights_data(plan_uuids, plan_details, base_plan_uuid, institution_uuid)
  end

  defp get_all_insights_data(plan_uuids, plan_details, base_plan_uuid, institution_uuid) do
    plans =
      Planning.Services.PlanQueries.get_plan_data(plan_uuids)
      |> convert_list_to_map()

    base_plan_info = Planning.Services.PlanQueries.get_plan(base_plan_uuid)

    plan_insights_count =
      plan_uuids
      |> get_plan_insights_count(plan_details)
      |> add_plan_name(plans)

    outcome_status =
      plan_uuids
      |> get_plan_outcome_status(plan_details)
      |> add_plan_name(plans)

    measure_status =
      plan_uuids
      |> get_plan_measure_status(plan_details)
      |> add_plan_name(plans)

    plan_measure_type =
      plan_uuids
      |> get_plan_measure_type(plan_details)
      |> add_plan_name(plans)

    plan_measure_methods = get_measure_method_count(plan_uuids, plan_details)

    plan_measure_method_count =
      plan_uuids
      |> get_multiple_plan_measure_method_count(plans, plan_measure_methods)

    plan_action_category_count =
      plan_uuids
      |> get_multiple_plan_action_count_by_category(plan_details, base_plan_uuid)
      |> add_plan_name(plans)

    institution_learning_outcomes =
      get_multiple_plans_institution_outcomes_mapping(
        institution_uuid,
        plan_uuids,
        plan_details,
        base_plan_info
      )
      |> add_plan_name(plans)

    comparison_plan_measure_methods =
      plan_measure_methods
      |> Enum.map(fn mm -> mm.measure_method end)
      |> Enum.uniq()

    action_budget_requests =
      plan_uuids
      |> get_action_budget_requests_for_plans(plan_details, institution_uuid)
      |> add_plan_name(plans)

    %{
      plan_insights_count: plan_insights_count,
      plan_outcome_status: outcome_status,
      plan_measure_method: plan_measure_method_count,
      plan_measure_type: plan_measure_type,
      plan_action_category: plan_action_category_count,
      plan_measure_status: measure_status,
      institution_learning_outcomes: institution_learning_outcomes,
      comparison_plan_measure_methods: comparison_plan_measure_methods,
      action_budget_requests: action_budget_requests
    }
  end

  @doc """
    Gets org nodes for compared plans

    ## Parameters
      - institution_uuid: uuid identifier for institution.
      - plan_uuid_list: list of Uuid identifiers of the plans.
  """
  def get_org_nodes_for_compared_plans(institution_uuid, plan_uuid_list) do
    all_orgs = Planning.Services.PlanQueries.get_all_organizations(institution_uuid)

    plan_uuid_list
    |> Enum.map(&get_plan_organizations(&1))
    |> List.flatten()
    |> Enum.map(&Plan.find_org_ancestors(all_orgs, &1.node_uuid))
    |> List.flatten()
  end

  defp get_mission_statement_for_reporting_year(organization_uuid, %{
         reporting_year_uuid: reporting_year_uuid,
         reporting_year_start_date: reporting_year_start_date
       }) do
    current_mission_statement =
      ClientManagementQueries.get_current_mission_statement_revision_with_reporting_year(
        organization_uuid,
        reporting_year_uuid
      )

    ## if no current mission statement get last active mission statement.
    case current_mission_statement do
      nil ->
        PlanReportQueries.get_last_active_mission_statement_revision(
          organization_uuid,
          reporting_year_start_date
        )
        |> get_mission_statement(organization_uuid)

      current_mission_statement ->
        current_mission_statement.statement
    end
  end

  defp get_mission_statement(mission_statement, organization_uuid) do
    case {mission_statement, organization_uuid} do
      {nil, ""} ->
        ""

      {nil, organization_uuid} ->
        PlanReportQueries.get_base_mission_statement(organization_uuid)
        |> get_mission_statement("")

      {ms, _} ->
        ms.statement
    end
  end

  defp get_rubric_granularity_type(@desire2learn, rubric) do
    MeasureQueries.get_rubric_result_settings(rubric["uuid"])
  end

  defp get_rubric_granularity_type(_, _), do: %{rubric_granularity_type: nil}

  defp get_assessment_results(@desire2learn, rubric) do
    %{rubric_granularity_type: rubric_granularity_type} =
      MeasureQueries.get_rubric_result_settings(rubric["uuid"])

    case rubric_granularity_type do
      @overall_score -> get_overall_score_assessment_results(rubric)
      _ -> get_criteria_group_assessment_results(rubric)
    end
  end

  defp get_assessment_results(@blackboard, rubric) do
    get_overall_score_assessment_results(rubric)
  end

  defp get_assessment_results(@canvas, rubric) do
    get_overall_score_assessment_results(rubric)
  end

  defp get_assessment_results(_, rubric) do
    get_criteria_group_assessment_results(rubric)
  end

  defp get_criteria_group_assessment_results(rubric) do
    selected_level_ids =
      MeasureQueries.get_external_report_rubric_levels(rubric["uuid"])
      |> Enum.map(fn level -> String.downcase(level["id"]) end)

    MeasureQueries.get_assessment_result(selected_level_ids, rubric["uuid"])
  end

  defp get_overall_score_assessment_results(rubric) do
    MeasureQueries.get_overall_score_assessment_result(rubric["uuid"])
  end

  defp get_measure_student_counts_result_files(plan_outcome_measure_uuid) do
    result_files =
      PlanReportQueries.get_measure_evidences(plan_outcome_measure_uuid)
      |> Enum.filter(fn evidence -> evidence.evidence_type == @student_counts end)

    %{result_files: result_files}
  end

  defp get_measurement_student_scores_data(
         nil,
         _student_scores,
         result_files,
         _measure_collect_score
       ),
       do: %{
         met_count: nil,
         notmet_count: nil,
         approached: nil,
         exceeded: nil,
         average: nil,
         min_score: nil,
         max_score: nil,
         number_of_scores_received: nil,
         result_granularity_type: nil,
         result_files: result_files
       }

  defp get_measurement_student_scores_data(
         %{result_granularity_type: "IndividualStudentScores"},
         student_scores,
         result_files,
         measure_collect_score
       ) do
    {exceeded_count, met_count, approached_count, notmet_count} =
      Measure.calculate_student_counts(student_scores, measure_collect_score.data)

    %{
      met_count: met_count,
      notmet_count: notmet_count,
      approached: approached_count,
      exceeded: exceeded_count,
      average: nil,
      min_score: nil,
      max_score: nil,
      number_of_scores_received: nil,
      result_granularity_type: "IndividualStudentScores",
      result_files: result_files
    }
  end

  defp get_measurement_student_scores_data(
         %{result_granularity_type: "AverageStudentScores"},
         student_scores,
         result_files,
         _measure_collect_score
       ) do
    average_result = Measure.calculate_student_average(student_scores)

    get_measurement_student_scores_average_results(
      average_result,
      "AverageStudentScores",
      result_files
    )
  end

  defp get_measurement_student_scores(plan_outcome_measure_uuid) do
    student_scores = MeasureQueries.get_submitted_student_scores(plan_outcome_measure_uuid)

    result_files =
      PlanReportQueries.get_measure_evidences(plan_outcome_measure_uuid)
      |> Enum.filter(fn evidence -> evidence.evidence_type == @student_scores end)

    measure_collect_score = Measure.get_measure_collect_score_data(plan_outcome_measure_uuid)

    get_measurement_student_scores_data(
      measure_collect_score.settings,
      student_scores,
      result_files,
      measure_collect_score
    )
  end

  defp get_measurement_student_scores_average_results(nil, result_granularity_type, result_files),
    do: %{
      met_count: nil,
      notmet_count: nil,
      approached: nil,
      exceeded: nil,
      average: nil,
      min_score: nil,
      max_score: nil,
      number_of_scores_received: nil,
      result_granularity_type: result_granularity_type,
      result_files: result_files
    }

  defp get_measurement_student_scores_average_results(
         average_result,
         result_granularity_type,
         result_files
       ),
       do: %{
         met_count: nil,
         notmet_count: nil,
         approached: nil,
         exceeded: nil,
         average: average_result.average,
         min_score: average_result.min_score,
         max_score: average_result.max_score,
         number_of_scores_received: average_result.total_count,
         result_granularity_type: result_granularity_type,
         result_files: result_files
       }

  defp get_plan_outcome_data(plan_outcome_data, plan_uuid, org_or_course_uuid) do
    action_data =
      PlanReportQueries.get_plan_actions_by_plan_outcome(
        plan_uuid,
        plan_outcome_data.outcome_uuid,
        org_or_course_uuid
      )

    measure_courses =
      plan_uuid
      |> PlanReportQueries.get_courses_for_measures_by_org(org_or_course_uuid)
      |> convert_list_to_map

    measure_actions =
      action_data
      |> Enum.filter(fn action -> not is_nil(action.plan_outcome_measure_uuid) end)
      |> format_actions()
      |> Enum.group_by(& &1.plan_outcome_measure_uuid)

    measure_data =
      plan_uuid
      |> PlanReportQueries.get_plan_measures_by_plan_outcome(
        plan_outcome_data.outcome_uuid,
        org_or_course_uuid
      )
      |> Enum.map(fn measure ->
        %{
          course: Map.get(measure_courses, measure.plan_outcome_measure_uuid, ""),
          measure_actions: Map.get(measure_actions, measure.plan_outcome_measure_uuid, [])
        }
        |> Map.merge(measure)
        |> Map.merge(
          get_measurement_results(
            measure.data_collection_method,
            measure.plan_outcome_measure_uuid
          )
        )
        |> Map.merge(get_description_documents_for_measure(measure.measure_uuid))
      end)

    outcome_actions =
      action_data
      |> Enum.filter(fn action -> is_nil(action.plan_outcome_measure_uuid) end)
      |> format_actions()

    %{measures: measure_data, actions: outcome_actions}
  end

  defp get_plan_outcomes_data(plan_outcome_data, plan_uuid, org_or_course_uuid) do
    action_data =
      PlanReportQueries.get_plan_actions_by_org_or_course(plan_uuid, org_or_course_uuid)

    measure_courses =
      PlanReportQueries.get_courses_for_measures_by_org(plan_uuid, org_or_course_uuid)
      |> convert_list_to_map

    measure_actions =
      action_data
      |> Enum.filter(fn action -> not is_nil(action.plan_outcome_measure_uuid) end)
      |> format_actions()
      |> Enum.group_by(& &1.plan_outcome_measure_uuid)

    measure_data =
      PlanReportQueries.get_plan_measures(plan_uuid, org_or_course_uuid)
      |> Enum.map(fn measure ->
        %{
          course: Map.get(measure_courses, measure.plan_outcome_measure_uuid, ""),
          measure_actions: Map.get(measure_actions, measure.plan_outcome_measure_uuid, [])
        }
        |> Map.merge(measure)
        |> Map.merge(
          get_measurement_results(
            measure.data_collection_method,
            measure.plan_outcome_measure_uuid
          )
        )
        |> Map.merge(get_description_documents_for_measure(measure.measure_uuid))
      end)
      |> Enum.group_by(& &1.outcome_uuid)

    outcome_actions =
      action_data
      |> Enum.filter(fn action -> is_nil(action.plan_outcome_measure_uuid) end)
      |> format_actions()
      |> Enum.group_by(& &1.outcome_uuid)

    plan_outcome_data
    |> Enum.map(fn outcome ->
      %{
        outcome_uuid: outcome.outcome_uuid,
        outcome_name: outcome.outcome_title,
        outcome_set_name: outcome.outcome_set_name,
        description: outcome.description,
        status: outcome.status,
        conclusion: outcome.conclusion,
        measures: Map.get(measure_data, outcome.outcome_uuid, []),
        outcome_actions: Map.get(outcome_actions, outcome.outcome_uuid, [])
      }
    end)
  end

  defp get_description_documents_for_measure(measure_uuid) do
    %{description_documents: PlanReportQueries.get_measure_attachments(measure_uuid)}
  end

  defp format_actions(actions) do
    actions
    |> Enum.map(fn a ->
      formatted_due_date =
        case a.due_date do
          nil -> ""
          date -> date |> Timex.format!("{0M}/{0D}/{YYYY}")
        end

      Map.put(a, :due_date, formatted_due_date)
    end)
  end

  defp get_action_count_by_category(plan_uuids, {plan_assessment_type, association_uuids}) do
    case plan_assessment_type do
      @course_plan ->
        PlanReportQueries.get_course_plans_action_count_by_category(plan_uuids, association_uuids)

      @program_plan ->
        PlanReportQueries.get_program_plans_action_count_by_category(
          plan_uuids,
          association_uuids
        )

      _ ->
        []
    end
  end

  defp get_action_count_by_category(
         base_plan_uuid,
         plan_uuids,
         {plan_assessment_type, association_uuids}
       ) do
    case plan_assessment_type do
      @course_plan ->
        PlanReportQueries.get_course_plans_action_count_by_category(
          base_plan_uuid,
          plan_uuids,
          association_uuids
        )

      @program_plan ->
        PlanReportQueries.get_program_plans_action_count_by_category(
          base_plan_uuid,
          plan_uuids,
          association_uuids
        )

      _ ->
        []
    end
  end

  defp get_measure_method_count(plan_uuids, {plan_assessment_type, association_uuids}) do
    case plan_assessment_type do
      @course_plan ->
        PlanReportQueries.get_course_plans_measure_method_count(association_uuids, plan_uuids)

      @program_plan ->
        PlanReportQueries.get_program_plans_measure_method_count(
          association_uuids,
          plan_uuids
        )

      _ ->
        []
    end
  end

  defp get_plan_organizations(plan_uuid) do
    plan = Planning.Services.PlanQueries.get_plan_info_by_uuid(plan_uuid)
    Plan.get_organization_data_for_plan(plan)
  end

  defp get_child_nodes_uuid_list(selected_node_uuid, institution_uuid) do
    nodes = Planning.Services.PlanReportQueries.get_nodes_for_hierarchy(institution_uuid)

    selected_node =
      nodes
      |> Enum.find(fn n -> n.uuid == selected_node_uuid end)

    nodes
    |> get_child_nodes(selected_node)
    |> List.flatten()
    |> Enum.map(fn c -> c.uuid end)
    |> Enum.uniq()
  end

  defp add_plan_name(data_list, plans) do
    data_list
    |> Enum.map(fn map ->
      plan_name = Map.get(plans, map.plan_uuid, "")
      Map.put(map, :plan_name, plan_name)
    end)
  end

  defp get_multiple_plans_institution_outcomes_mapping(
         institution_uuid,
         plan_uuids,
         plan_details,
         base_plan_info
       ) do
    institution_level_outcomes =
      AccountManagementQueries.get_root_organization!(institution_uuid)
      |> Map.get(:uuid)
      |> OutcomeSetQueries.get_outcomes_for_organization()

    institution_level_outcomes
    |> Stream.map(fn outcome ->
      Planning.Measure.get_current_revision_outcome_details(outcome.outcome_uuid, base_plan_info)
    end)
    |> Stream.flat_map(&get_mapped_outcome_status_count_for_plans(&1, plan_uuids, plan_details))
    |> Enum.to_list()
  end

  defp get_mapped_outcome_status_count_for_plans(
         outcome,
         plan_uuids,
         plan_details
       ) do
    parent_outcome_uuid = get_parent_outcome_uuid(outcome)
    outcome_uuids = OutcomeSetQueries.get_mappings_for_outcome(parent_outcome_uuid)

    plan_outcomes =
      outcome_uuids
      |> get_outcome_count_by_status(plan_uuids, plan_details)
      |> Enum.group_by(& &1.plan_uuid)

    plan_data =
      generate_comparison_ilo_data(
        plan_details,
        plan_uuids,
        outcome_uuids,
        plan_outcomes,
        outcome
      )

    org_details = get_unique_mapped_orgs(plan_data)

    plan_data
    |> Enum.map(fn plan ->
      ilo_mappings = plan.outcome_mapping_by_organization

      if Enum.empty?(ilo_mappings) do
        add_remaining_org_details(org_details, plan)
      else
        add_unmapped_org_to_plan(ilo_mappings, org_details, plan)
      end
    end)
  end

  defp add_unmapped_org_to_plan(ilo_mappings, org_details, plan) do
    orgs_in_ilo = Enum.map(ilo_mappings, & &1.course_or_org_uuid)

    remaining_orgs =
      Enum.filter(org_details, fn {org_uuid, _org_name} ->
        not Enum.member?(orgs_in_ilo, org_uuid)
      end)

    add_remaining_org_details(remaining_orgs, plan)
  end

  defp get_clo_to_plo_chart_data(
         plan_uuid,
         program_with_mappings
       ) do
    updated_programs =
      program_with_mappings
      |> Enum.map(fn program ->
        clos_in_plan =
          get_course_plan_outcomes_mapped_to_program(plan_uuid, program.clo_to_plo_mappings)

        # Update clo to plo mappings by adding plan outcome status
        # and reject the outcomes which are not aligned in plan
        updated_program = update_program_outcome_mappings(program, clos_in_plan)

        # Update Program map by adding count of outcomes by their status
        add_count_of_mapped_outcomes_by_status(updated_program, :clo_to_plo_mappings)
      end)

    updated_programs
    |> update_program_mappings_by_plo()
    |> update_outcome_revisions(plan_uuid)
  end

  defp get_clo_to_plo_mappings_for_programs(institution_uuid, plan_uuid, association_uuids) do
    program_with_mappings =
      plan_uuid
      |> PlanReportQueries.get_clo_to_plo_mappings(association_uuids, institution_uuid)
      |> Enum.group_by(&Map.take(&1, [:org_uuid, :org_name]))
      |> Enum.map(fn {program, mappings} ->
        Map.put(program, :clo_to_plo_mappings, mappings)
      end)

    plan_uuid
    |> get_clo_to_plo_chart_data(program_with_mappings)
  end

  defp get_clo_to_plo_mappings_by_program(plan, clo_to_plo_mappings) do
    program_mappings =
      clo_to_plo_mappings
      |> Enum.group_by(&Map.take(&1, [:org_uuid, :org_name]))
      |> Enum.map(fn {program, mappings} ->
        Map.put(program, :clo_to_plo_mappings, mappings)
      end)

    plan_assessment_type = get_plan_assessment_type(plan.assessment_type_id)

    courses_mapped_with_program =
      clo_to_plo_mappings
      |> Enum.map(& &1.course_uuid)

    {plan.plan_uuid
     |> get_clo_to_plo_chart_data(program_mappings),
     {plan_assessment_type, courses_mapped_with_program}}
  end

  defp get_course_plan_outcomes_mapped_to_program(plan_uuid, clo_to_plo_mappings) do
    clo_to_plo_mappings
    |> Enum.map(& &1.clo_uuid)
    |> PlanReportQueries.get_course_plan_outcomes_mapped_to_program(plan_uuid)
  end

  defp update_program_outcome_mappings(program, clos_in_plan) do
    updated_mappings =
      program.clo_to_plo_mappings
      |> Enum.flat_map(fn mapping ->
        clos_in_plan
        |> Enum.map(fn clo ->
          if clo.course_uuid == mapping.course_uuid &&
               clo.outcome_uuid == mapping.clo_uuid do
            Map.merge(mapping, %{
              active_outcome_revision: clo.active_outcome_revision,
              plan_outcome_status: clo.plan_outcome_status
            })
          end
        end)
        # To reject nil values from list
        |> Enum.reject(&(!&1))
      end)

    Map.replace!(program, :clo_to_plo_mappings, updated_mappings)
  end

  defp add_count_of_mapped_outcomes_by_status(map, key) do
    mapping_count =
      map
      |> Map.get(key, [])
      |> Enum.group_by(& &1.plan_outcome_status)
      |> Enum.reduce(
        %{met_count: 0, not_met_count: 0, in_progress_count: 0},
        fn {outcome_status, outcome_mappings}, acc ->
          count =
            outcome_mappings
            |> Enum.map(& &1.clo_uuid)
            |> Enum.uniq()
            |> Enum.count()

          case outcome_status do
            @outcome_met -> Map.replace!(acc, :met_count, count)
            @outcome_not_met -> Map.replace!(acc, :not_met_count, count)
            _ -> Map.replace!(acc, :in_progress_count, count)
          end
        end
      )

    Map.merge(map, mapping_count)
  end

  defp update_program_mappings_by_plo(programs) do
    programs
    |> Enum.map(fn program ->
      updated_mappings =
        program.clo_to_plo_mappings
        |> Enum.group_by(&Map.take(&1, [:plo_uuid, :plo_title, :plo_sort_order]))
        |> Enum.sort_by(fn {key, _value} -> key.plo_sort_order end)
        |> Enum.map(fn {plo, clos} ->
          plo
          |> Map.put(:plo_mappings, clos)
          |> add_count_of_mapped_outcomes_by_status(:plo_mappings)
        end)

      Map.replace!(program, :clo_to_plo_mappings, updated_mappings)
    end)
  end

  defp update_outcome_revisions(programs_with_mappings, plan_uuid) do
    current_reporting_year = PlanReportQueries.get_plan_reporting_year(plan_uuid)

    previous_reporting_years =
      StrategicPlanQueries.get_previous_reporting_years(
        current_reporting_year.institution_uuid,
        current_reporting_year.start_date
      )

    # get revisions
    outcome_revisions =
      programs_with_mappings
      |> get_outcome_uuids_from_program_mappings()
      |> PlanReportQueries.get_outcome_with_revisions()

    # update revisions
    programs_with_mappings
    |> Enum.map(fn plo_program_mapping ->
      plo_program_mapping
      |> update_plo_program_mapping(
        outcome_revisions,
        current_reporting_year,
        previous_reporting_years
      )
    end)
  end

  defp get_outcome_uuids_from_program_mappings(programs_with_mappings) do
    programs_with_mappings
    |> Enum.map(fn x -> x.clo_to_plo_mappings end)
    |> List.flatten()
    |> Enum.map(fn x -> x.plo_mappings end)
    |> List.flatten()
    |> Enum.map(fn o -> [o.active_outcome_revision, o.plo_uuid, o.clo_uuid] end)
    |> List.flatten()
    |> Enum.uniq()
  end

  defp update_plo_program_mapping(
         plo_program_mapping,
         outcome_revisions,
         current_reporting_year,
         previous_reporting_years
       ) do
    updated_clo_to_plo_mappings =
      plo_program_mapping.clo_to_plo_mappings
      |> Enum.map(fn clo_to_plo_mapping ->
        clo_to_plo_mapping
        |> update_clo_to_plo_mapping(
          outcome_revisions,
          current_reporting_year,
          previous_reporting_years
        )
      end)

    plo_program_mapping
    |> Map.put(:clo_to_plo_mappings, updated_clo_to_plo_mappings)
  end

  defp update_clo_to_plo_mapping(
         clo_to_plo_mapping,
         outcome_revisions,
         current_reporting_year,
         previous_reporting_years
       ) do
    plo_revision_by_ry =
      outcome_revisions
      |> Enum.find(fn outcome_revision ->
        outcome_revision.uuid == clo_to_plo_mapping.plo_uuid
      end)
      |> get_outcome_revision(current_reporting_year, previous_reporting_years)

    updated_plo_mappings =
      clo_to_plo_mapping.plo_mappings
      |> Enum.map(fn plo_mapping ->
        plo_mapping
        |> update_plo_mapping(
          outcome_revisions,
          current_reporting_year,
          previous_reporting_years
        )
      end)

    clo_to_plo_mapping
    |> Map.put(:plo_mappings, updated_plo_mappings)
    |> Map.put(:plo_title, plo_revision_by_ry.title)
  end

  defp update_plo_mapping(
         plo_mapping,
         outcome_revisions,
         current_reporting_year,
         previous_reporting_years
       ) do
    outcome_uuid = plo_mapping.active_outcome_revision || plo_mapping.clo_uuid

    clo_revision_by_ry =
      outcome_revisions
      |> Enum.find(fn outcome_revision ->
        outcome_revision.uuid == outcome_uuid
      end)
      |> get_outcome_revision(current_reporting_year, previous_reporting_years)

    # update clo info with its revision
    plo_mapping
    |> Map.put(:is_clo_archived, clo_revision_by_ry.is_archived)
    |> Map.put(:clo_title, clo_revision_by_ry.title)
  end

  # This function will perform following operations
  # 1. It will check if any revision exists for an outcome
  #   1.1 if found any it will invoke get_outcome_active_revision function,
  #   1.2 otherwise will return base outcome.
  # 2. After finding the appropriate outcome, it will format it to update is_archived and uuid.

  @doc """
    Get outcome detail, if found any revision for current or previous reporting years
    then, take the current active revision detail and format it, if no revisons exists
    then, take the base outcome details to return in formatted map.

    ## Parameters
      - outcome - Data struct  of Outcome
      - current_reporting_year - Data struct of Reporting Year
      - previous_reporting_years - Data struct list of previous Reporting Year
  """

  def get_outcome_revision(outcome, current_reporting_year, previous_reporting_years) do
    current_revision =
      if Enum.empty?(outcome.outcome_revisions) do
        outcome
      else
        outcome
        |> get_outcome_active_revision(
          current_reporting_year,
          previous_reporting_years
        )
      end

    %{
      is_archived: outcome.is_archived,
      title: current_revision.title,
      outcome_uuid: outcome.uuid
    }
  end

  # This function will perform the following operations
  # 1. It will first check outcome's revision for current reporting year
  #   i.e passed as second parameter and return the revision if found any.
  # 2. Otherwise it will check outcome's revision for previous reporting years
  #   i.e passed ad third parameter and return the revision if found any.
  # 3. Otherwise base outcome will be returned.
  defp get_outcome_active_revision(
         outcome,
         current_reporting_year,
         previous_reporting_years
       ) do
    filtered_outcomes =
      get_outcome_revisions_filtered_by_reporting_year(
        outcome.outcome_revisions,
        current_reporting_year
      )

    if Enum.empty?(filtered_outcomes) do
      outcome.outcome_revisions
      |> get_outcome_revision_for_past_reporting_years(previous_reporting_years) ||
        outcome
    else
      get_active_revision(filtered_outcomes)
    end
  end

  # This function will filter the outcome's revisions created for a particular reporting year.
  defp get_outcome_revisions_filtered_by_reporting_year(outcome_revisions, reporting_year) do
    outcome_revisions
    |> Enum.filter(fn ov -> ov.reporting_year_uuid == reporting_year.uuid end)
  end

  # This function will perform the following operations
  # 1. It will iterate over the sorted list of passed reporting years.
  # 2. It will check if outcome's revision exists for that year or not.
  # 3. if outcome's revision is found for any reporting year in the list.
  #   3.1 that revision will be returned.
  #   3.2 otherwise nil will be returned.
  defp get_outcome_revision_for_past_reporting_years(outcome_revisions, reporting_years) do
    reporting_years
    |> Enum.find_value(fn ry ->
      filtered_outcomes = get_outcome_revisions_filtered_by_reporting_year(outcome_revisions, ry)

      if Enum.empty?(filtered_outcomes) do
        nil
      else
        get_active_revision(filtered_outcomes)
      end
    end)
  end

  # This function will return the latest revision of an outcome, if more than one exist.
  defp get_active_revision(outcome_revisions) do
    outcome_revisions
    |> Enum.sort_by(& &1.inserted_at, &Timex.after?/2)
    |> hd
  end

  defp generate_comparison_ilo_data(
         plan_details,
         plan_uuids,
         outcome_uuids,
         plan_outcomes,
         outcome
       ) do
    plan_uuids
    |> Enum.map(fn plan_uuid ->
      outcome_mapping_by_organization =
        get_ilo_mappings_by_plan_type(plan_details, outcome_uuids, plan_uuid)

      %{title: plan_title} = PlanQueries.get_plan_info_by_uuid(plan_uuid)

      case Map.get(plan_outcomes, plan_uuid) do
        nil ->
          %{
            in_progress_count: 0,
            met_count: 0,
            not_met_count: 0,
            plan_uuid: plan_uuid,
            plan_title: plan_title,
            outcome_uuid: get_parent_outcome_uuid(outcome),
            outcome_title: outcome.title,
            is_gen_ed_outcome: outcome.is_gen_ed_outcome,
            outcome_mapping_by_organization: []
          }

        outcomes ->
          outcomes
          |> Enum.reduce(%{met_count: 0, not_met_count: 0, in_progress_count: 0}, fn po, acc ->
            update_outcome_status_count(po, acc)
          end)
          |> Map.merge(%{
            plan_uuid: plan_uuid,
            plan_title: plan_title,
            outcome_uuid: get_parent_outcome_uuid(outcome),
            outcome_title: outcome.title,
            is_gen_ed_outcome: outcome.is_gen_ed_outcome,
            outcome_mapping_by_organization: outcome_mapping_by_organization
          })
      end
    end)
  end

  defp add_remaining_org_details(org_details, plan) do
    new_orgs =
      org_details
      |> Enum.map(fn {org_uuid, org_name} ->
        %{
          in_progress_count: 0,
          met_count: 0,
          course_or_org_name: org_name,
          course_or_org_uuid: org_uuid,
          not_met_count: 0,
          plan_title: plan.plan_title,
          plan_uuid: plan.plan_uuid
        }
      end)

    Map.put(
      plan,
      :outcome_mapping_by_organization,
      plan.outcome_mapping_by_organization ++ new_orgs
    )
  end

  defp get_unique_mapped_orgs(data) do
    data
    |> Enum.reduce(%{}, fn plan, acc ->
      Enum.reduce(plan.outcome_mapping_by_organization, acc, fn mapping, old_acc ->
        Map.put(old_acc, mapping.course_or_org_uuid, mapping.course_or_org_name)
      end)
    end)
  end

  defp get_multiple_plan_measure_method_count(plan_uuids, plan_data, plan_measure_methods) do
    measure_method_count_map =
      plan_measure_methods
      |> Enum.group_by(& &1.plan_uuid)

    plan_uuids
    |> Enum.map(fn plan_uuid ->
      plan_name = Map.get(plan_data, plan_uuid, "")

      get_measure_method_map(
        plan_uuid,
        Map.get(measure_method_count_map, plan_uuid, %{}),
        plan_name
      )
    end)
  end

  defp get_measure_method_map(plan_uuid, plan_measure_method_count, plan_name) do
    default_data = %{plan_uuid: plan_uuid, plan_name: plan_name}

    if Enum.empty?(plan_measure_method_count) do
      %{
        Direct: default_data,
        Indirect: default_data
      }
    else
      get_measure_method_data(default_data, plan_measure_method_count)
    end
  end

  defp get_measure_method_data(default_data, plan_measure_method_count) do
    measure_data =
      plan_measure_method_count
      |> Enum.group_by(& &1.measure_type)

    ["Direct", "Indirect"]
    |> Enum.map(fn key ->
      counts =
        Map.get(measure_data, key, %{})
        |> Enum.reduce(%{}, fn measure, acc ->
          Map.put(acc, measure.measure_method, measure.measure_count)
        end)
        |> Map.merge(default_data)

      %{String.to_atom(key) => counts}
    end)
    |> convert_list_to_map
  end

  defp get_multiple_plan_action_count_by_category(plan_uuids, plan_details, base_plan_uuid) do
    action_category_count_map =
      get_action_count_by_category(base_plan_uuid, plan_uuids, plan_details)
      |> Enum.group_by(& &1.plan_uuid)

    plan_uuids
    |> Enum.map(fn plan ->
      get_action_category_map(plan, Map.get(action_category_count_map, plan, %{}))
    end)
  end

  defp get_action_category_map(plan_uuid, plan_action_category_count) do
    if Enum.empty?(plan_action_category_count) do
      %{plan_uuid: plan_uuid}
    else
      plan_action_category_count
      |> Enum.reduce(%{}, fn action, acc ->
        Map.put(acc, action.action_category, action.action_category_count)
      end)
      |> Map.put(:plan_uuid, plan_uuid)
    end
  end

  defp convert_list_to_map(data_list) do
    data_list
    |> Enum.reduce(%{}, fn n, acc ->
      Map.merge(acc, n)
    end)
  end

  defp sort_outcomes_based_on_sort_order(outcomes) do
    outcomes
    |> Enum.group_by(& &1.is_archived)
    |> Enum.map(fn {key, value} ->
      if key do
        value |> Enum.sort(&(&1.outcome_name <= &2.outcome_name))
      else
        value |> Enum.sort(&(&1.sort_order <= &2.sort_order))
      end
    end)
    |> List.flatten()
  end

  defp get_institution_outcomes_mapping(institution_uuid, plan_uuid, plan_details) do
    plan = PlanQueries.get_plan(plan_uuid)

    institution_level_outcomes =
      AccountManagementQueries.get_root_organization!(institution_uuid)
      |> Map.get(:uuid)
      |> OutcomeSetQueries.get_outcomes_for_organization()

    institution_level_outcomes
    |> Enum.map(fn outcome ->
      current_outcome_revision =
        Planning.Measure.get_current_revision_outcome_details(outcome.outcome_uuid, plan)

      case OutcomeSetQueries.get_mappings_for_outcome(outcome.outcome_uuid) do
        [] ->
          get_empty_outcome_status_count(current_outcome_revision)

        _ ->
          get_outcome_status_count_by_mapping(current_outcome_revision, plan_uuid, plan_details)
      end
    end)
  end

  defp get_outcome_status_count_by_mapping(
         outcome,
         plan_uuid,
         plan_details
       ) do
    outcome_uuid = get_parent_outcome_uuid(outcome)

    outcome_uuids = OutcomeSetQueries.get_mappings_for_outcome(outcome_uuid)

    outcome_status_count =
      outcome_uuids
      |> get_outcome_count_by_status([plan_uuid], plan_details)
      |> Enum.reduce(%{met_count: 0, not_met_count: 0, in_progress_count: 0}, fn po, acc ->
        update_outcome_status_count(po, acc)
      end)

    outcome_mapping_by_organization =
      get_ilo_mappings_by_plan_type(plan_details, outcome_uuids, plan_uuid)

    %{
      outcome_uuid: get_parent_outcome_uuid(outcome),
      outcome_title: outcome.title,
      is_gen_ed_outcome: outcome.is_gen_ed_outcome,
      met_count: outcome_status_count.met_count,
      not_met_count: outcome_status_count.not_met_count,
      in_progress_count: outcome_status_count.in_progress_count,
      outcome_mapping_by_organization: outcome_mapping_by_organization
    }
  end

  defp get_ilo_mappings_by_plan_type({plan_type, association_uuids}, outcome_uuids, plan_uuid) do
    case plan_type do
      @program_plan ->
        get_ilo_mappings_by_organization(outcome_uuids, plan_uuid, association_uuids)

      @course_plan ->
        get_ilo_mappings_by_course(outcome_uuids, plan_uuid, association_uuids)
    end
  end

  defp get_ilo_mappings_by_organization(outcome_uuids, plan_uuid, organization_uuids) do
    %{title: plan_title} = PlanQueries.get_plan_info_by_uuid(plan_uuid)

    PlanReportQueries.get_outcome_status_count_per_organization(
      outcome_uuids,
      plan_uuid,
      organization_uuids
    )
    |> Enum.group_by(& &1.organization_uuid)
    |> Enum.map(fn {_organization, outcomes} ->
      outcomes
      |> Enum.reduce(%{met_count: 0, not_met_count: 0, in_progress_count: 0}, fn o, acc ->
        organization_info = %{
          course_or_org_uuid: o.organization_uuid,
          course_or_org_name: o.organization_name,
          plan_uuid: o.plan_uuid,
          plan_title: plan_title
        }

        update_outcome_status_count(o, acc)
        |> Map.merge(organization_info)
      end)
    end)
  end

  defp get_ilo_mappings_by_course(outcome_uuids, plan_uuid, course_uuids) do
    %{title: title} = PlanQueries.get_plan_info_by_uuid(plan_uuid)

    PlanReportQueries.get_outcome_status_count_per_course(outcome_uuids, plan_uuid, course_uuids)
    |> Enum.group_by(& &1.course_uuid)
    |> Enum.map(fn {_course_uuid, outcomes} ->
      outcomes
      |> Enum.reduce(%{met_count: 0, not_met_count: 0, in_progress_count: 0}, fn o, acc ->
        course_info = %{
          course_or_org_uuid: o.course_uuid,
          course_or_org_name: o.course_code,
          plan_uuid: o.plan_uuid,
          plan_title: title
        }

        update_outcome_status_count(o, acc)
        |> Map.merge(course_info)
      end)
    end)
  end

  defp get_plan_measure_status(plan_uuids, {plan_assessment_type, association_uuids}) do
    measure_status_counts =
      case plan_assessment_type do
        @program_plan ->
          PlanReportQueries.get_program_plans_measure_status(plan_uuids, association_uuids)

        @course_plan ->
          PlanReportQueries.get_course_plans_measure_status(plan_uuids, association_uuids)

        _ ->
          []
      end

    total_plan_measure_count =
      case plan_assessment_type do
        @course_plan ->
          PlanReportQueries.get_measure_count_for_course_plans(association_uuids, plan_uuids)

        @program_plan ->
          PlanReportQueries.get_measure_count_for_program_plans(association_uuids, plan_uuids)

        _ ->
          []
      end

    plan_uuids
    |> Enum.map(fn plan_uuid ->
      plan_measure_status_count = Enum.filter(measure_status_counts, &(&1.plan_uuid == plan_uuid))

      plan_measure_count =
        total_plan_measure_count
        |> Enum.find(%{}, &Map.get(&1, plan_uuid))
        |> Map.get(plan_uuid, 0)

      get_measure_status_map(plan_measure_status_count, plan_measure_count)
      |> Map.put(:plan_uuid, plan_uuid)
    end)
  end

  defp get_measure_status_map(measure_status_counts, total_count) do
    if Enum.empty?(measure_status_counts) || total_count == 0 do
      %{met: 0, not_met: 0, unspecified: 0}
    else
      measure_status_counts
      |> Enum.reduce(%{}, fn measure, acc ->
        case measure.measure_result do
          true -> Map.put(acc, :met, measure.count)
          false -> Map.put(acc, :not_met, measure.count)
          _ -> Map.put(acc, :unspecified, measure.count)
        end
      end)
    end
  end

  defp get_plan_measure_type(plan_uuids, {plan_assessment_type, association_uuids}) do
    measure_type_counts_map =
      case plan_assessment_type do
        @course_plan ->
          PlanReportQueries.get_plan_measure_type_for_course_plans(plan_uuids, association_uuids)

        @program_plan ->
          PlanReportQueries.get_plan_measure_type_for_program_plans(plan_uuids, association_uuids)
      end
      |> Enum.group_by(& &1.plan_uuid)

    measure_count_map =
      case plan_assessment_type do
        @course_plan ->
          PlanReportQueries.get_measure_count_for_course_plans(association_uuids, plan_uuids)

        @program_plan ->
          PlanReportQueries.get_measure_count_for_program_plans(association_uuids, plan_uuids)

        _ ->
          []
      end
      |> convert_list_to_map()

    plan_uuids
    |> Enum.map(fn plan ->
      plan_measure_type_counts = Map.get(measure_type_counts_map, plan, %{})

      total_plan_measure_count = Map.get(measure_count_map, plan, 0)

      get_measure_type_map(plan, plan_measure_type_counts, total_plan_measure_count)
    end)
  end

  defp get_measure_type_map(plan_uuid, plan_measure_type_counts, total_count) do
    if Enum.empty?(plan_measure_type_counts) || total_count == 0 do
      %{plan_uuid: plan_uuid, direct: 0, indirect: 0, unspecified: 0}
    else
      plan_measure_type_counts
      |> Enum.reduce(%{}, fn measure, acc ->
        case measure.type do
          "Direct" -> Map.put(acc, :direct, measure.count)
          "Indirect" -> Map.put(acc, :indirect, measure.count)
          _ -> Map.put(acc, :unspecified, measure.count)
        end
      end)
      |> Map.put(:plan_uuid, plan_uuid)
    end
  end

  defp get_plan_insights_count(plan_uuids, {plan_assessment_type, association_uuids}) do
    overview_data =
      case plan_assessment_type do
        @course_plan ->
          get_course_plan_overview_data(plan_uuids, association_uuids)

        @program_plan ->
          get_program_plan_overview_data(plan_uuids, association_uuids)
      end

    measure_count =
      case plan_assessment_type do
        @course_plan ->
          PlanReportQueries.get_measure_count_for_course_plans(association_uuids, plan_uuids)

        @program_plan ->
          PlanReportQueries.get_measure_count_for_program_plans(association_uuids, plan_uuids)

        _ ->
          []
      end
      |> convert_list_to_map()

    action_count =
      case plan_assessment_type do
        @course_plan ->
          PlanReportQueries.get_action_count_for_course_plans(plan_uuids, association_uuids)

        @program_plan ->
          PlanReportQueries.get_action_count_for_program_plans(plan_uuids, association_uuids)

        _ ->
          []
      end
      |> convert_list_to_map()

    populate_plan_insights_count(plan_uuids, overview_data, measure_count, action_count)
  end

  defp get_course_plan_overview_data(plan_uuids, course_uuids) do
    {plan_uuids
     |> PlanReportQueries.get_participating_course_count(course_uuids)
     |> convert_list_to_map(),
     plan_uuids
     |> PlanReportQueries.get_course_count_for_plan(course_uuids)
     |> convert_list_to_map(),
     plan_uuids
     |> PlanReportQueries.get_course_plans_outcomes_count(course_uuids)
     |> convert_list_to_map(),
     plan_uuids
     |> PlanReportQueries.get_conclusion_count_for_course_plan(course_uuids)
     |> convert_list_to_map()}
  end

  defp get_program_plan_overview_data(plan_uuids, node_uuids) do
    {plan_uuids
     |> PlanReportQueries.get_participating_organizations_in_program_plans(node_uuids)
     |> convert_list_to_map(),
     plan_uuids
     |> PlanReportQueries.get_program_plans_nodes(node_uuids)
     |> convert_list_to_map(),
     plan_uuids
     |> PlanReportQueries.get_program_plans_outcome_count(node_uuids)
     |> convert_list_to_map(),
     plan_uuids
     |> PlanReportQueries.get_conclusion_count_for_program_plans(node_uuids)
     |> convert_list_to_map()}
  end

  defp populate_plan_insights_count(
         plan_uuids,
         {participating_orgs, org_count, outcome_count, conclusion_count},
         measure_count,
         action_count
       ) do
    plan_uuids
    |> Enum.map(fn plan_uuid ->
      %{
        plan_uuid: plan_uuid,
        org_count: Map.get(org_count, plan_uuid, 0),
        participating_orgs: Map.get(participating_orgs, plan_uuid, 0),
        outcome_count: Map.get(outcome_count, plan_uuid, 0),
        measure_count: Map.get(measure_count, plan_uuid, 0),
        conclusion_count: Map.get(conclusion_count, plan_uuid, 0),
        action_count: Map.get(action_count, plan_uuid, 0)
      }
    end)
  end

  defp get_plan_outcome_status(plan_uuids, {plan_assessment_type, association_uuids}) do
    {outcome_status_counts, total_plan_outcome_count} =
      case plan_assessment_type do
        @course_plan ->
          {PlanReportQueries.get_course_plans_outcome_status(plan_uuids, association_uuids),
           PlanReportQueries.get_course_plans_outcomes_count(plan_uuids, association_uuids)}

        @program_plan ->
          {PlanReportQueries.get_program_plans_outcome_status(plan_uuids, association_uuids),
           PlanReportQueries.get_program_plans_outcome_count(plan_uuids, association_uuids)}

        _ ->
          {%{}, %{}}
      end

    plan_uuids
    |> Enum.map(fn plan_uuid ->
      plan_outcome_status_count = Enum.filter(outcome_status_counts, &(&1.plan_uuid == plan_uuid))

      plan_outcome_count =
        total_plan_outcome_count
        |> Enum.find(%{}, &Map.get(&1, plan_uuid))
        |> Map.get(plan_uuid, 0)

      get_outcome_status_map(plan_outcome_status_count, plan_outcome_count)
      |> Map.put(:plan_uuid, plan_uuid)
    end)
  end

  defp get_outcome_status_map(outcome_status_counts, total_count) do
    if Enum.empty?(outcome_status_counts) || total_count == 0 do
      %{met: 0, not_met: 0, unspecified: 0}
    else
      outcome_status_counts
      |> Enum.reduce(%{}, fn outcome, acc ->
        case outcome.status do
          @outcome_met -> Map.put(acc, :met, outcome.count)
          @outcome_not_met -> Map.put(acc, :not_met, outcome.count)
          _ -> Map.put(acc, :unspecified, outcome.count)
        end
      end)
    end
  end

  defp get_outcome_count_by_status(
         outcome_uuids,
         plan_uuids,
         {plan_assessment_type, association_uuids}
       ) do
    case plan_assessment_type do
      @program_plan ->
        PlanReportQueries.get_program_outcome_count_by_status(
          outcome_uuids,
          plan_uuids,
          association_uuids
        )

      @course_plan ->
        PlanReportQueries.get_course_outcome_count_by_status(
          outcome_uuids,
          plan_uuids,
          association_uuids
        )
    end
  end

  defp update_outcome_status_count(outcome, acc) do
    case outcome.outcome_status do
      @outcome_met -> Map.replace!(acc, :met_count, outcome.outcome_status_count)
      @outcome_not_met -> Map.replace!(acc, :not_met_count, outcome.outcome_status_count)
      _ -> Map.replace!(acc, :in_progress_count, outcome.outcome_status_count)
    end
  end

  defp get_empty_outcome_status_count(outcome) do
    %{
      outcome_uuid: get_parent_outcome_uuid(outcome),
      outcome_title: outcome.title,
      is_gen_ed_outcome: outcome.is_gen_ed_outcome,
      met_count: 0,
      not_met_count: 0,
      in_progress_count: 0,
      outcome_mapping_by_organization: []
    }
  end

  defp get_parent_outcome_uuid(%{uuid: uuid, parent_outcome: nil}), do: uuid
  defp get_parent_outcome_uuid(%{parent_outcome: parent_outcome}), do: parent_outcome

  defp get_action_budget_requests_for_plans(
         plan_uuids,
         {plan_assessment_type, association_uuids},
         institution_uuid
       ) do
    total_budget_requests =
      case plan_assessment_type do
        @course_plan ->
          PlanReportQueries.get_action_budget_requests_for_course_plans(
            plan_uuids,
            association_uuids
          )

        @program_plan ->
          PlanReportQueries.get_action_budget_requests_for_program_plans(
            plan_uuids,
            association_uuids
          )

        _ ->
          []
      end
      |> convert_list_to_map()

    budget_request_detail =
      case PlanQueries.get_budget_request_by_institution(institution_uuid) do
        nil -> %{is_enabled: false, currency_code: ""}
        _ -> PlanQueries.get_budget_request_with_currency_code(institution_uuid)
      end

    get_action_budget_request_map(plan_uuids, total_budget_requests, budget_request_detail)
  end

  defp get_action_budget_request_map(
         plan_uuids,
         aggregate_budget_requests,
         budget_request_detail
       ) do
    plan_uuids
    |> Enum.map(fn plan_uuid ->
      %{
        plan_uuid: plan_uuid,
        budget_amount: Map.get(aggregate_budget_requests, plan_uuid, 0)
      }
      |> Map.merge(budget_request_detail)
    end)
  end

  defp get_budget_request_data(institution_uuid) do
    PlanQueries.get_budget_request_by_institution(institution_uuid)
    |> case do
      nil -> %{is_budget_request_on: false, budget_currency_code: ""}
      budget_request -> get_budget_request_details(budget_request.is_enabled, institution_uuid)
    end
  end

  defp get_budget_request_details(is_enabled, institution_uuid) do
    budget_currency_code =
      if is_enabled do
        institution_uuid
        |> PlanQueries.get_budget_request_with_currency_code()
        |> get_budget_currency_code()
      else
        ""
      end

    %{is_budget_request_on: is_enabled, budget_currency_code: budget_currency_code}
  end

  defp get_child_nodes(all_nodes, node) do
    children =
      all_nodes
      |> Enum.filter(fn n ->
        n.parent_uuid == node.uuid
      end)

    case children do
      [] ->
        [node]

      children ->
        built_children =
          children
          |> Enum.map(fn c -> get_child_nodes(all_nodes, c) end)

        [node | built_children]
    end
  end

  defp get_plan_type_and_available_nodes(
         base_plan_uuid,
         plan_uuids,
         available_orgs
       ) do
    plan = PlanQueries.get_plan_info_by_uuid(base_plan_uuid)

    orgs =
      case plan.assessment_type_id do
        @program_assessment_type ->
          available_orgs

        _ ->
          PlanQueries.get_courses_for_available_orgs(plan_uuids, available_orgs)
      end

    {get_plan_assessment_type(plan.assessment_type_id), orgs}
  end

  defp get_plan_assessment_type(0), do: @program_plan
  defp get_plan_assessment_type(1), do: @course_plan

  defp get_budget_currency_code(budget_currency) do
    case budget_currency do
      nil -> ""
      _ -> budget_currency.currency_code
    end
  end

  defp prepare_measure_result_data(results, measure_data) do
    measure_data
    |> Enum.map(fn measure ->
      results
      |> Map.get(measure.plan_outcome_measure_uuid, [])
      |> merge_measure_result(measure)
    end)
    |> List.flatten()
  end

  defp merge_measure_result([], measure) do
    measure
    |> Map.merge(%{
      result_source: measure.source,
      not_met_count: "",
      met_count: "",
      criteria: nil
    })
  end

  defp merge_measure_result(results, measure) do
    Enum.map(results, &Map.merge(measure, &1))
  end

  defp get_overall_result_data([]), do: []

  defp get_overall_result_data(plan_outcome_measure_uuids) do
    plan_outcome_measure_uuids
    |> PlanReportQueries.get_overall_result_data()
    |> Enum.map(fn result ->
      {met_percent, not_met_percent} = calculate_result_percent(result)
      Map.merge(result, %{met_count: met_percent, not_met_count: not_met_percent})
    end)
  end

  defp calculate_result_percent(result) do
    met_count = result.met_count || 0
    not_met_count = result.not_met_count || 0

    (met_count + not_met_count)
    |> case do
      0 ->
        {"", ""}

      total ->
        met_percent = (met_count * 100 / total) |> round()
        {met_percent, 100 - met_percent}
    end
  end

  defp get_internal_results_data([]), do: []

  defp get_internal_results_data(plan_outcome_measure_uuids) do
    {data_with_each_student_count_final, internal_result_data_filtered} =
      plan_outcome_measure_uuids
      |> PlanReportQueries.get_internal_results_data()
      |> evaluate_internal_results_for_each_student_count()

    {data_with_individual_student_scores_final, internal_result_data_filtered_final} =
      evaluate_internal_results_for_individual_student_scores(internal_result_data_filtered)

    (data_with_each_student_count_final ++
       data_with_individual_student_scores_final ++
       (internal_result_data_filtered_final
        |> Enum.map(&evaluate_internal_results(&1))))
    |> Enum.uniq()
  end

  defp evaluate_internal_results(%{
         pom_uuid: pom_uuid,
         data_collection_method: _,
         measurement_collect_score: nil,
         measurement_collect_individual_score: nil,
         measurement_collect_average_score: nil,
         measurement_student_count: nil,
         measurement_overall_student_count: nil
       }) do
    %{
      plan_outcome_measure_uuid: pom_uuid,
      result_source: nil,
      not_met_count: nil,
      met_count: nil,
      criteria: nil
    }
  end

  defp evaluate_internal_results(%{
         pom_uuid: pom_uuid,
         data_collection_method: "StudentScores",
         measurement_collect_score: %{result_granularity_type: "AverageStudentScores"}
       }) do
    %{
      plan_outcome_measure_uuid: pom_uuid,
      result_source: nil,
      not_met_count: nil,
      met_count: nil,
      criteria: nil
    }
  end

  defp evaluate_internal_results(%{
         pom_uuid: pom_uuid,
         data_collection_method: "StudentCounts",
         measurement_student_count: %{granularity_type: "OverallStudentCounts"},
         measurement_overall_student_count: mosc
       })
       when is_nil(mosc) == false do
    %{
      plan_outcome_measure_uuid: pom_uuid,
      result_source: nil,
      not_met_count:
        calculate_percentage(mosc.met, mosc.exceeded, mosc.notmet, mosc.approached, :not_met),
      met_count:
        calculate_percentage(mosc.met, mosc.exceeded, mosc.notmet, mosc.approached, :met),
      criteria: nil
    }
  end

  defp evaluate_internal_results(%{
         pom_uuid: pom_uuid,
         data_collection_method: "StudentCounts",
         measurement_student_count: %{granularity_type: "OverallStudentCounts"},
         measurement_overall_student_count: nil
       }) do
    %{
      plan_outcome_measure_uuid: pom_uuid,
      result_source: nil,
      not_met_count: nil,
      met_count: nil,
      criteria: nil
    }
  end

  defp calculate_student_counts(student_scores, score_bucket) do
    List.foldl(student_scores, {0, 0, 0, 0}, fn score, {exceeded, met, approached, notmet} ->
      cond do
        is_nil(score) ->
          {exceeded, met, approached, notmet}

        score <= score_bucket.not_met ->
          {exceeded, met, approached, notmet + 1}

        score_bucket.approached &&
            (score > score_bucket.not_met &&
               score <= score_bucket.approached) ->
          {exceeded, met, approached + 1, notmet}

        is_nil(score_bucket.approached) &&
            (score > score_bucket.not_met && score <= score_bucket.met) ->
          {exceeded, met + 1, approached, notmet}

        score_bucket.max_score && score > score_bucket.met ->
          {exceeded + 1, met, approached, notmet}

        true ->
          {exceeded, met + 1, approached, notmet}
      end
    end)
  end

  defp evaluate_internal_results_for_each_student_count(result_data) do
    {data_with_each_student_count, internal_result_data_filtered} =
      result_data
      |> Enum.split_with(fn x ->
        x.data_collection_method == "StudentCounts" &&
          (x |> Map.get(:measurement_student_count) || %{}) |> Map.get(:granularity_type) ==
            "EachStudentCounts"
      end)

    data_with_each_student_count_final =
      if Enum.empty?(data_with_each_student_count) do
        data_with_each_student_count
      else
        data_with_each_student_count
        |> Enum.map(& &1.pom_uuid)
        |> PlanReportQueries.get_internal_results_for_section_student_count()
        |> Enum.map(
          &%{
            plan_outcome_measure_uuid: &1.plan_outcome_measure_uuid,
            result_source: nil,
            not_met_count:
              calculate_percentage(&1.met, &1.exceeded, &1.notmet, &1.approached, :not_met),
            met_count: calculate_percentage(&1.met, &1.exceeded, &1.notmet, &1.approached, :met),
            criteria: nil
          }
        )
      end

    {data_with_each_student_count_final, internal_result_data_filtered}
  end

  defp evaluate_internal_results_for_individual_student_scores(result_data) do
    {data_with_individual_student_scores, internal_result_data_filtered} =
      result_data
      |> Enum.split_with(fn x ->
        x.data_collection_method == "StudentScores" &&
          (x |> Map.get(:measurement_collect_score) || %{}) |> Map.get(:result_granularity_type) ==
            "IndividualStudentScores"
      end)

    data_with_individual_student_scores_final =
      if Enum.empty?(data_with_individual_student_scores) do
        data_with_individual_student_scores
      else
        pom_uuids =
          data_with_individual_student_scores
          |> Enum.map(& &1.pom_uuid)

        scores_data =
          pom_uuids
          |> PlanReportQueries.get_submitted_student_scores()
          |> Enum.group_by(& &1.plan_outcome_measure_uuid)
          |> Enum.into(%{}, fn {pom_uuid, submitted_student_scores} ->
            {pom_uuid, submitted_student_scores |> Enum.map(& &1.score)}
          end)

        if Enum.empty?(scores_data) do
          data_with_individual_student_scores
          |> Enum.map(
            &%{
              plan_outcome_measure_uuid: &1.pom_uuid,
              result_source: nil,
              not_met_count: nil,
              met_count: nil,
              criteria: nil
            }
          )
        else
          data_with_individual_student_scores
          |> Enum.map(fn score_bucket ->
            {exceeded_count, met_count, approached_count, notmet_count} =
              scores_data
              |> Map.get(score_bucket.pom_uuid, [])
              |> calculate_student_counts(score_bucket.measurement_collect_individual_score)

            {final_not_met_count, final_met_count} =
              calculate_percentage_data_for_student_counts(
                exceeded_count,
                met_count,
                approached_count,
                notmet_count
              )

            %{
              plan_outcome_measure_uuid: score_bucket.pom_uuid,
              result_source: nil,
              not_met_count: final_not_met_count,
              met_count: final_met_count,
              criteria: nil
            }
          end)
        end
      end

    {data_with_individual_student_scores_final, internal_result_data_filtered}
  end

  defp calculate_percentage_data_for_student_counts(
         exceeded_count,
         met_count,
         approached_count,
         notmet_count
       ) do
    if {exceeded_count, met_count, approached_count, notmet_count} == {0, 0, 0, 0} do
      {nil, nil}
    else
      {
        calculate_percentage(
          met_count,
          exceeded_count,
          notmet_count,
          approached_count,
          :not_met
        ),
        calculate_percentage(
          met_count,
          exceeded_count,
          notmet_count,
          approached_count,
          :met
        )
      }
    end
  end

  defp format_count_data(met, exceed, not_met, approached) do
    {(met || 0) + (exceed || 0), (not_met || 0) + (approached || 0),
     (met || 0) + (exceed || 0) + ((not_met || 0) + (approached || 0))}
  end

  defp calculate_percentage(met, exceed, not_met, approached, type) do
    {met, not_met, total} = format_count_data(met, exceed, not_met, approached)

    case {type, total > 0} do
      {:met, true} ->
        round(met / total * 100)

      {:not_met, true} ->
        round(not_met / total * 100)

      {_, _} ->
        nil
    end
  end

  def get_versioned_outcomes(measure_results) do
    case List.first(measure_results) do
      nil ->
        {:ok, []}

      measure_result ->
        plan_outcome_uuids = measure_results |> Enum.map(& &1.outcome_uuid) |> Enum.uniq()

        get_current_outcome_revisions(
          {plan_outcome_uuids, measure_result.reporting_year_uuid, measure_result.start_date}
        )
    end
  end

  defp get_result_data_for_multiple_criterias([]) do
    []
  end

  defp get_result_data_for_multiple_criterias(plan_outcome_measure_uuids) do
    grouped_levels_data_by_rubric =
      PlanReportQueries.get_external_report_rubrics_level_data(plan_outcome_measure_uuids)
      |> Enum.group_by(& &1.rubric_uuid)

    grouped_levels_data_by_rubric
    |> Map.keys()
    |> PlanReportQueries.get_assessment_results_for_rubrics()
    |> Enum.group_by(&{&1.rubric_uuid, &1.criteria_id, &1.criteria_name})
    |> Enum.map(fn {{rubric_uuid, _, _} = criteria_result_key, criteria_result_value} ->
      selected_levels_for_rubric =
        grouped_levels_data_by_rubric
        |> Map.get(rubric_uuid)

      rubric_data =
        selected_levels_for_rubric
        |> List.first()

      selected_level_ids =
        selected_levels_for_rubric
        |> Enum.map(fn level -> String.downcase(level.id) end)

      get_criteria_based_result_data_per_rubric(
        criteria_result_value,
        rubric_data,
        selected_level_ids,
        criteria_result_key
      )
    end)
  end

  defp get_criteria_based_result_data_per_rubric(
         levels_result,
         rubric_data,
         selected_level_ids,
         {rubric_uuid, criteria_id, criteria_name}
       ) do
    {met_count, not_met_count} =
      levels_result
      |> Enum.reduce({0, 0}, fn criteria_data, {met_count, not_met_count} ->
        if Enum.find(
             selected_level_ids,
             fn level -> criteria_data.level_id == level end
           ) do
          {met_count + criteria_data.count, not_met_count}
        else
          {met_count, not_met_count + criteria_data.count}
        end
      end)

    total_count = met_count + not_met_count

    {met_count_perc, not_met_count_perc} =
      case total_count do
        0 ->
          {0, 0}

        _ ->
          {round(met_count / total_count * 100), round(not_met_count / total_count * 100)}
      end

    %{
      rubric_uuid: rubric_uuid,
      criteria_id: criteria_id,
      met_count: met_count_perc,
      not_met_count: not_met_count_perc,
      criteria: criteria_name,
      plan_outcome_measure_uuid: rubric_data.plan_outcome_measure_uuid,
      result_source: rubric_data.result_source
    }
  end
end
