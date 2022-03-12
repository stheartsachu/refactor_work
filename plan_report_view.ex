defmodule EISWeb.Api.PlanReportView do
  use EISWeb, :view
  use CSV.Defaults
  @complete 1
  def render("res.json", %{res: res}) do
    res
  end

  def render("plan_outcome_report.json", %{res: res}) do
    plan_info = %{plan_name: res.plan_name, reporting_year_name: res.reporting_year_name}
    org_data = prepare_org_data(res)

    %{
      plan_info: plan_info,
      org_data: org_data,
      budget_currency_code: res.budget_currency_code,
      is_outcome_page: false,
      count_categories_nomenclature: res.count_categories_nomenclature,
      is_plan_outcome_report: true
    }
  end

  def render("available_nodes.json", %{nodes: nodes}) do
    nodes
    |> Enum.map(&format_org_nodes(&1))
    |> Enum.uniq()
  end

  def render("measure_detail_report.json", %{data: measure_data}) do
    report_data =
      [
        get_common_report_headers() ++
          [
            gettext("Method Type"),
            gettext("Measure Title"),
            gettext("Measure Description"),
            gettext("Course Code"),
            gettext("Course Name"),
            gettext("Term(s)"),
            gettext("Target"),
            gettext("Measure Result"),
            gettext("Last Updated On"),
            gettext("Last Updated By")
          ]
      ] ++ get_program_plan_measure_detail_report_data(measure_data)

    file_name = gettext("Plan_Measure_Detail_") <> get_current_date() <> ".csv"
    csv_contents(report_data, file_name)
  end

  def render("measure_result_report.json", %{data: measure_result_data}) do
    report_data =
      [
        [
          gettext("Plan Title"),
          gettext("Reporting Year"),
          gettext("Organization"),
          gettext("Lead"),
          gettext("Outcome Title"),
          gettext("Outcome Description"),
          gettext("Is Outcome Archived?"),
          gettext("Measure Type"),
          gettext("Measure Title"),
          gettext("Measure Description"),
          gettext("Course Code"),
          gettext("Course Name"),
          gettext("Result Type"),
          gettext("Result Source"),
          gettext("Measure Status"),
          gettext("Criteria"),
          gettext("Met %"),
          gettext("Not Met %")
        ]
      ] ++ get_program_plan_measure_result_report_data(measure_result_data)

    file_name = gettext("Plan_Measure_Results_") <> get_current_date() <> ".csv"
    csv_contents(report_data, file_name)
  end

  def render("outcome_detail_report.json", %{
        data: %{
          report_data: report_data,
          org_leads: org_leads,
          outcome_revisions: outcome_revisions
        }
      }) do
    org_leads =
      org_leads
      |> Enum.group_by(& &1.organization_uuid, & &1.user)

    outcome_revisons_map =
      Enum.map(outcome_revisions, fn outcome_revision ->
        {outcome_revision.parent_outcome, outcome_revision}
      end)

    data =
      report_data
      |> Enum.map(fn org_data ->
        {revised_outcome_title, revised_outcome_desc, revised_outcome_tags} =
          get_revised_outcome_detail(org_data, outcome_revisons_map)

        [
          org_data.plan_title,
          org_data.plan_period,
          org_data.org_name,
          get_organization_type_translation(org_data.org_type),
          get_leads(org_data.org_uuid, org_leads),
          revised_outcome_title,
          revised_outcome_desc,
          get_outcome_archived_details(org_data.is_archived),
          org_data.outcome_set_name,
          format_outcome_tags(revised_outcome_tags),
          org_data.total_measure_count,
          org_data.measures_with_result,
          decode_outcome_status(org_data.plan_outcome_status),
          org_data.conclusion,
          org_data.action_count,
          format_last_update_date(org_data.last_updated_on),
          org_data.last_updated_by
        ]
      end)

    report_data =
      [
        get_common_report_headers() ++
          [
            gettext("Measures"),
            gettext("Measure with Results"),
            gettext("Outcome Status"),
            gettext("Conclusion"),
            gettext("Actions"),
            gettext("Last Updated On"),
            gettext("Last Updated By")
          ]
      ] ++ data

    file_name = gettext("Plan_Outcome_Detail_") <> get_current_date() <> ".csv"

    csv_contents(report_data, file_name)
  end

  def render(
        "organization_summary_report.json",
        %{data: data}
      ) do
    report_data =
      [
        [
          gettext("Plan Title"),
          gettext("Reporting Year"),
          gettext("Organization"),
          gettext("Organization Type"),
          gettext("Assessment Lead"),
          gettext("Mission"),
          gettext("Overall Plan Status"),
          gettext("Total Number of Outcomes"),
          gettext("Total Number of Outcomes in this Plan"),
          gettext("Total Number of Measures"),
          gettext("Total Number of Actions"),
          gettext("Met Objectives"),
          gettext("Last Updated On"),
          gettext("Last Updated By")
        ]
      ] ++ generate_organization_summary_report(data)

    file_name = gettext("Plan_Organizational_Progress_Summary_") <> get_current_date() <> ".csv"
    csv_contents(report_data, file_name)
  end

  def render("action_detail_report.json", %{data: action_data}) do
    report_data =
      [
        get_common_report_headers() ++
          [gettext("Action Type"), gettext("Action Status"), gettext("Action Description")] ++
          get_report_headers_for_budget_request(
            action_data.budget_request_data.is_budget_request_on
          ) ++
          [
            gettext("Recommended Due Date"),
            gettext("Last Updated On"),
            gettext("Last Updated By")
          ]
      ] ++ generate_program_plan_action_detail_report_data(action_data)

    file_name = gettext("Plan_Action_Detail_") <> get_current_date() <> ".csv"
    csv_contents(report_data, file_name)
  end

  def render("course_plan_action_detail_report.json", %{data: action_data}) do
    report_data =
      [
        get_course_plan_report_common_headers() ++
          [gettext("Action Type"), gettext("Action Status"), gettext("Action Description")] ++
          get_report_headers_for_budget_request(
            action_data.budget_request_data.is_budget_request_on
          ) ++
          [
            gettext("Recommended Due Date"),
            gettext("Last Updated On"),
            gettext("Last Updated By")
          ]
      ] ++ generate_course_plan_action_detail_report_data(action_data)

    file_name = gettext("Plan_Action_Detail_") <> get_current_date() <> ".csv"
    csv_contents(report_data, file_name)
  end

  def render("course_plan_measure_detail_report.json", %{data: measure_data}) do
    report_data =
      [
        get_course_plan_measure_report_headers()
      ] ++ generate_course_plan_measure_detail_report_data(measure_data)

    file_name = gettext("Plan_Measure_Detail_") <> get_current_date() <> ".csv"
    csv_contents(report_data, file_name)
  end

  def render("course_plan_outcome_detail_report.json", %{data: outcome_data}) do
    report_data =
      [
        get_course_plan_outcome_report_headers()
      ] ++ generate_course_plan_outcome_detail_report_data(outcome_data)

    file_name = gettext("Plan_Outcome_Detail_") <> get_current_date() <> ".csv"
    csv_contents(report_data, file_name)
  end

  defp generate_course_plan_action_detail_report_data(%{
         report_data: report_data,
         org_leads: org_leads,
         course_leads: course_leads,
         budget_request_data: budget_request_data
       }) do
    org_leads =
      org_leads
      |> Enum.group_by(& &1.organization_uuid, & &1.user)

    course_leads =
      course_leads
      |> Enum.group_by(& &1.course_uuid, & &1.user)

    report_data
    |> Enum.map(fn data ->
      [
        data.plan_title,
        data.reporting_year,
        data.organization_name,
        get_organization_type_translation(data.organization_type),
        get_leads(data.organization_uuid, org_leads),
        data.course_name,
        data.course_code,
        get_leads(data.course_uuid, course_leads),
        data.outcome_title,
        data.outcome_desc,
        get_outcome_archived_details(data.is_archived),
        data.outcome_set_name,
        format_outcome_tags(data.outcome_tags),
        decode_action_category(data.action_category, data.action_other_category),
        decode_action_status(data.action_status_id, data.action_category),
        data.action_desc
      ] ++
        get_budget_request_data(
          data.budget_description,
          data.budget_amount,
          budget_request_data
        ) ++
        [
          format_action_due_date(data.action_due_date),
          format_last_update_date(data.last_updated_on),
          data.last_updated_by
        ]
    end)
  end

  defp generate_course_plan_measure_detail_report_data(%{
         report_data: report_data,
         course_leads: course_leads
       }) do
    course_leads =
      course_leads
      |> Enum.group_by(& &1.course_uuid, & &1.user)

    report_data
    |> Enum.map(fn data ->
      [
        data.plan_title,
        data.reporting_year,
        data.terms |> Enum.join(", "),
        data.organization_name,
        data.course_code,
        data.course_name,
        get_leads(data.course_uuid, course_leads),
        data.outcome_set_name,
        data.outcome_title,
        data.outcome_desc,
        get_outcome_archived_details(data.is_archived),
        format_outcome_tags(data.outcome_tags),
        data.aligned_program,
        decode_measure_method(data.measure_method),
        data.measure_title,
        data.measure_desc,
        data.measure_target,
        data.measure_result,
        format_last_update_date(data.last_updated_on),
        data.last_updated_by
      ]
    end)
  end

  defp generate_course_plan_outcome_detail_report_data(%{
         report_data: report_data,
         course_leads: course_leads,
         outcome_revisions: outcome_revisions,
         outcome_measures: outcome_measures
       }) do
    course_leads =
      course_leads
      |> Enum.group_by(& &1.course_uuid, & &1.user)

    outcome_revisons_map =
      Enum.map(outcome_revisions, fn outcome_revision ->
        {outcome_revision.parent_outcome, outcome_revision}
      end)

    report_data
    |> Enum.map(fn data ->
      {revised_outcome_title, revised_outcome_desc, revised_outcome_tags} =
        get_revised_outcome_detail(data, outcome_revisons_map)

      [
        data.plan_title,
        data.reporting_year,
        data.terms |> Enum.join(", "),
        data.course_parent,
        data.course_code,
        data.course_name,
        get_leads(data.course_uuid, course_leads),
        revised_outcome_title,
        revised_outcome_desc,
        get_outcome_archived_details(data.is_archived),
        format_outcome_tags(revised_outcome_tags),
        data.measure_count,
        data.measures_result,
        decode_course_outcome_status(data, outcome_measures),
        data.outcome_analysis,
        data.actions_count,
        format_last_update_date(data.last_updated_at),
        data.last_updated_by
      ]
    end)
  end

  defp get_course_plan_report_common_headers() do
    [
      gettext("Plan Title"),
      gettext("Reporting Year"),
      gettext("Organization"),
      gettext("Organization Type"),
      gettext("Lead"),
      gettext("Course Name"),
      gettext("Course Number"),
      gettext("Lead"),
      gettext("Outcome Title"),
      gettext("Outcome Description"),
      gettext("Is Outcome Archived?"),
      gettext("Outcome Set Name"),
      gettext("Outcome Tags")
    ]
  end

  defp get_revised_outcome_detail(report_data, []) do
    {report_data.outcome_title, report_data.outcome_desc, report_data.outcome_tags}
  end

  defp get_revised_outcome_detail(report_data, outcome_revisions) do
    outcome_revisions
    |> List.keyfind(report_data.outcome_uuid, 0)
    |> case do
      nil ->
        {report_data.outcome_title, report_data.outcome_desc, report_data.outcome_tags}

      {_, revision} ->
        {revision.title, revision.description, revision.outcome_tags}
    end
  end

  defp get_course_plan_measure_report_headers() do
    [
      gettext("Plan Title"),
      gettext("Reporting Year"),
      gettext("Term(s)"),
      gettext("Course Parent"),
      gettext("Course Code"),
      gettext("Course Title"),
      gettext("Course Lead"),
      gettext("Course Outcome Set Name"),
      gettext("Course Outcome Title"),
      gettext("Course Outcome Description"),
      gettext("Is Outcome Archived?"),
      gettext("Outcome Tags"),
      gettext("Aligned Program Name"),
      gettext("Method Type"),
      gettext("Measure Title"),
      gettext("Measure Description"),
      gettext("Target"),
      gettext("Measure Status"),
      gettext("Last Updated On"),
      gettext("Last Updated By")
    ]
  end

  defp format_org_nodes(org) do
    %{uuid: org.uuid, parent_uuid: org.parent_uuid, name: org.name, type: org.type}
  end

  defp csv_contents(report_data, file_name) do
    data =
      report_data
      |> CSV.encode()
      |> Enum.to_list()
      |> to_string

    %{report_data: data, file_name: file_name}
  end

  defp get_course_plan_outcome_report_headers() do
    [
      gettext("Plan Title"),
      gettext("Reporting Year"),
      gettext("Terms"),
      gettext("Course Parent"),
      gettext("Course Code"),
      gettext("Course Title"),
      gettext("Course Lead"),
      gettext("Course Outcome Title"),
      gettext("Course Outcome Description"),
      gettext("Is Outcome Archived?"),
      gettext("Outcome Tags"),
      gettext("Measures"),
      gettext("Measure with Results"),
      gettext("Outcome Status"),
      gettext("Outcome Analysis"),
      gettext("Actions"),
      gettext("Last Updated On"),
      gettext("Last Updated By")
    ]
  end

  defp get_common_report_headers() do
    [
      gettext("Plan Title"),
      gettext("Reporting Year"),
      gettext("Organization"),
      gettext("Organization Type"),
      gettext("Lead"),
      gettext("Outcome Title"),
      gettext("Outcome Description"),
      gettext("Is Outcome Archived?"),
      gettext("Outcome Set Name"),
      gettext("Outcome Tags")
    ]
  end

  def get_organization_type_translation(organization_type) do
    case organization_type do
      "Institution" -> gettext("Institution")
      "Department" -> gettext("Department")
      "School" -> gettext("School")
      "Program" -> gettext("Program")
      "College" -> gettext("College")
      "Division" -> gettext("Division")
      "Center" -> gettext("Center")
      "Institute" -> gettext("Institute")
      "Unit" -> gettext("Unit")
      "Course" -> gettext("Course")
      _ -> organization_type
    end
  end

  defp get_program_plan_measure_detail_report_data(%{
         report_data: report_data,
         outcome_revisions: outcome_revisions,
         org_leads: org_leads,
         measure_terms: measure_terms
       }) do
    org_leads =
      org_leads
      |> Enum.group_by(& &1.organization_uuid, & &1.user)

    outcome_revisons_map =
      Enum.map(outcome_revisions, fn outcome_revision ->
        {outcome_revision.parent_outcome, outcome_revision}
      end)
      |> IO.inspect(label: "outcome revision map")

    report_data
    |> Enum.map(fn data ->
      {revised_outcome_title, revised_outcome_desc, revised_outcome_tags} =
        get_revised_outcome_detail(data, outcome_revisons_map)
        |> IO.inspect(label: "revised outcome detail")

      [
        data.plan_title,
        data.reporting_year,
        data.organization_name,
        get_organization_type_translation(data.organization_type),
        get_leads(data.organization_uuid, org_leads),
        revised_outcome_title,
        revised_outcome_desc,
        get_outcome_archived_details(data.is_archived),
        data.outcome_set_name,
        format_outcome_tags(revised_outcome_tags),
        decode_measure_method(data.measure_method),
        data.measure_title,
        data.measure_desc,
        data.course_code,
        data.course_name,
        get_measure_terms(data.plan_outcome_measure_uuid, measure_terms),
        data.measure_target,
        decode_measure_result(data.measure_result),
        format_last_update_date(data.last_updated_on),
        data.last_updated_by
      ]
    end)
  end

  defp get_program_plan_measure_result_report_data(%{
         report_data: report_data,
         org_leads: org_leads,
         versioned_outcomes: versioned_outcomes
       }) do
    org_leads =
      org_leads
      |> Enum.group_by(& &1.organization_uuid, & &1.user)

    report_data
    |> Enum.map(fn data ->
      {revised_outcome_title, revised_outcome_desc, _revised_outcome_tags} =
        get_revised_outcome_detail(data, versioned_outcomes)

      [
        data.plan_title,
        data.reporting_year,
        data.organization_name,
        get_leads(data.organization_uuid, org_leads),
        revised_outcome_title,
        revised_outcome_desc,
        get_outcome_archived_details(data.is_archived),
        decode_measure_method(data.measure_method),
        data.measure_title,
        data.measure_desc,
        decode_course_name_or_code(data.course_code),
        decode_course_name_or_code(data.course_name),
        translate_result_type(data.measure_data_collection),
        get_result_source(data.result_source),
        decode_measure_result(data.measure_result, ""),
        format_result_criteria(data.criteria, data.source),
        format_result_count(data.met_count, data.measure_data_collection),
        format_result_count(data.not_met_count, data.measure_data_collection)
      ]
    end)
  end

  defp get_measure_terms(nil, _) do
    ""
  end

  defp get_measure_terms(plan_outcome_measure_uuid, measure_terms) do
    case Map.has_key?(measure_terms, plan_outcome_measure_uuid) do
      false ->
        ""

      true ->
        get_measure_terms_by_plan_outcome_measure_uuid(measure_terms, plan_outcome_measure_uuid)
    end
  end

  defp get_measure_terms_by_plan_outcome_measure_uuid(measure_terms, plan_outcome_measure_uuid) do
    Map.get(measure_terms, plan_outcome_measure_uuid)
    |> Enum.join(", ")
  end

  defp get_leads(organization_uuid, org_leads) do
    case Map.has_key?(org_leads, organization_uuid) do
      false -> gettext("Unassigned")
      true -> get_lead_details(org_leads, organization_uuid)
    end
  end

  defp get_lead_details(org_leads, organization_uuid) do
    Map.get(org_leads, organization_uuid)
    |> Enum.map(fn user ->
      user.first_name <> " " <> user.last_name <> " <" <> user.email <> "> "
    end)
    |> Enum.join(", ")
  end

  defp get_result_source("aqua"), do: "Outcomes Assessment Projects"
  defp get_result_source("via"), do: "Student Learning & Licensure"
  defp get_result_source("canvas"), do: "Canvas"
  defp get_result_source("blackboard"), do: "Blackboard Learn"
  defp get_result_source("desire2learn"), do: "D2L Brightspace"
  defp get_result_source(_), do: "N/A"
  defp decode_measure_method("AssignmentDirect"), do: gettext("Assignment - Direct")
  defp decode_measure_method("CapstoneDirect"), do: gettext("Capstone - Direct")

  defp decode_measure_method("ExamCertificationOrLicensureDirect"),
    do: gettext("Exam (Certification/Licensure) - Direct")

  defp decode_measure_method("ExamCourseDirect"), do: gettext("Exam (Course) - Direct")
  defp decode_measure_method("FieldAssessmentDirect"), do: gettext("Field Assessment - Direct")
  defp decode_measure_method("PerformanceDirect"), do: gettext("Performance - Direct")
  defp decode_measure_method("PortfolioDirect"), do: gettext("Portfolio - Direct")
  defp decode_measure_method("PresentationDirect"), do: gettext("Presentation - Direct")
  defp decode_measure_method("ProjectDirect"), do: gettext("Project - Direct")
  defp decode_measure_method("QuizCourseDirect"), do: gettext("Quiz (Course) - Direct")
  defp decode_measure_method("OtherDirect"), do: gettext("Other - Direct")

  defp decode_measure_method("CompletionRatesIndirect"),
    do: gettext("Completion Rates - Indirect")

  defp decode_measure_method("CourseEvaluationIndirect"),
    do: gettext("Course Evaluation - Indirect")

  defp decode_measure_method("FocusGroupIndirect"), do: gettext("Focus Group - Indirect")
  defp decode_measure_method("InterviewIndirect"), do: gettext("Interview - Indirect")

  defp decode_measure_method("OverallCourseGradeIndirect"),
    do: gettext("Overall Course Grade - Indirect")

  defp decode_measure_method("SurveyIndirect"), do: gettext("Survey - Indirect")
  defp decode_measure_method("OtherIndirect"), do: gettext("Other - Indirect")
  defp decode_measure_method(_), do: ""

  defp decode_course_name_or_code(nil), do: "N/A"
  defp decode_course_name_or_code(name_or_code), do: name_or_code

  defp decode_measure_result(status, default \\ "")
  defp decode_measure_result(true, _default), do: gettext("Met")
  defp decode_measure_result(false, _default), do: gettext("Not Met")
  defp decode_measure_result(_, default), do: default
  defp format_result_criteria(nil, "aqua"), do: ""
  defp format_result_criteria(nil, "via"), do: ""
  defp format_result_criteria(nil, _), do: "N/A"
  defp format_result_criteria(criteria, _), do: criteria

  defp decode_outcome_status(outcome, outcome_measures, actions) do
    case outcome.outcome_status do
      "met" ->
        gettext("Met")

      "not met" ->
        gettext("Not Met")

      _ ->
        decode_empty_outcome_status(outcome, outcome_measures, actions)
    end
  end

  defp decode_outcome_status("met"), do: gettext("Met")
  defp decode_outcome_status("not met"), do: gettext("Not Met")

  defp decode_outcome_status(_), do: ""

  defp translate_result_type("ExternalReports"),
    do: gettext("I want to align results from another system")

  defp translate_result_type("StudentScores"),
    do: gettext("I want to send emails and collect scores from faculty")

  defp translate_result_type("StudentCounts"),
    do: gettext("I want to enter the count of students who meet/do not meet the criteria")

  defp translate_result_type("FileUpload"),
    do: gettext("I want to upload the assessment results files")

  defp translate_result_type(_), do: ""

  defp format_result_count(_result_count, "FileUpload"), do: "N/A"
  defp format_result_count(nil, _), do: ""
  defp format_result_count(-1, _), do: ""
  defp format_result_count("", _result_type), do: ""
  defp format_result_count(result_count, _result_type), do: to_string(result_count) <> " %"

  defp decode_empty_outcome_status(outcome, outcome_measures, actions) do
    if not Enum.empty?(actions) ||
         not Enum.empty?(Enum.filter(outcome_measures, & &1.is_data_entered)) ||
         (outcome.outcome_analysis != "" and outcome.outcome_analysis != nil) do
      gettext("In Progress")
    else
      gettext("Not Started")
    end
  end

  defp format_last_update_date(date) when is_nil(date), do: ""

  defp format_last_update_date(date) do
    date |> Timex.format!("{0M}/{0D}/{YYYY} {h24}:{0m} {am}")
  end

  defp decode_course_outcome_status(outcome, outcome_measures) do
    case outcome.outcome_status do
      "met" ->
        gettext("Met")

      "not met" ->
        gettext("Not Met")

      _ ->
        decode_empty_course_outcome_status(outcome, outcome_measures)
    end
  end

  defp decode_empty_course_outcome_status(outcome, outcome_measures) do
    if outcome.actions_count > 0 ||
         Enum.member?(outcome_measures, outcome.outcome_uuid) ||
         outcome.outcome_analysis != "" do
      gettext("In Progress")
    else
      gettext("Not Started")
    end
  end

  defp format_outcome_tags(tags) when is_nil(tags), do: ""

  defp format_outcome_tags(tags) do
    tags
    |> Enum.join(", ")
  end

  # Action Detail Report
  defp generate_program_plan_action_detail_report_data(%{
         report_data: report_data,
         outcome_revisions: outcome_revisions,
         org_leads: org_leads,
         budget_request_data: budget_request_data
       }) do
    org_leads =
      org_leads
      |> Enum.group_by(& &1.organization_uuid, & &1.user)

    outcome_revisons_map =
      Enum.map(outcome_revisions, fn outcome_revision ->
        {outcome_revision.parent_outcome, outcome_revision}
      end)

    report_data
    |> Enum.map(fn data ->
      {revised_outcome_title, revised_outcome_desc, revised_outcome_tags} =
        get_revised_outcome_detail(data, outcome_revisons_map)

      [
        data.plan_title,
        data.reporting_year,
        data.organization_name,
        get_organization_type_translation(data.organization_type),
        get_leads(data.organization_uuid, org_leads),
        revised_outcome_title,
        revised_outcome_desc,
        get_outcome_archived_details(data.is_archived),
        data.outcome_set_name,
        format_outcome_tags(revised_outcome_tags),
        decode_action_category(data.action_category, data.action_other_category),
        decode_action_status(data.action_status_id, data.action_category),
        data.action_desc
      ] ++
        get_budget_request_data(
          data.budget_description,
          data.budget_amount,
          budget_request_data
        ) ++
        [
          format_action_due_date(data.action_due_date),
          format_last_update_date(data.last_updated_on),
          data.last_updated_by
        ]
    end)
  end

  defp generate_organization_summary_report(%{
         report_data: report_data,
         org_leads: org_leads,
         total_plan_outcomes_count: total_plan_outcomes_count,
         measure_count: measure_count,
         total_outcomes_count: total_outcomes_count,
         action_count: action_count
       }) do
    report_data
    |> Enum.map(fn org_data ->
      plan_outcomes_data = Map.get(total_plan_outcomes_count, org_data.org_uuid, %{})

      plan_outcomes_count = Map.get(plan_outcomes_data, :plan_outcome_count, 0)

      last_updated_on = Map.get(plan_outcomes_data, :last_updated_on)
      last_updated_by = Map.get(plan_outcomes_data, :last_updated_by, "")

      org_status =
        case {org_data.org_status, org_data.plan_status} do
          {"Completed", _} -> gettext("Complete")
          {"Not Started", _} -> gettext("Not Started")
          {_, @complete} -> gettext("Incomplete")
          {_, _} -> gettext("In Progress")
        end

      [
        org_data.plan_title,
        org_data.plan_period,
        org_data.org_name,
        get_organization_type_translation(org_data.org_type),
        get_leads(org_data.org_uuid, org_leads),
        org_data.mission_statement,
        org_status,
        Map.get(total_outcomes_count, org_data.org_uuid, 0),
        plan_outcomes_count,
        Map.get(measure_count, org_data.org_uuid, 0),
        Map.get(action_count, org_data.org_uuid, 0),
        "#{org_data.met_plan_outcomes} #{gettext("of")} #{plan_outcomes_count}",
        format_last_update_date(last_updated_on),
        last_updated_by
      ]
    end)
  end

  defp get_budget_request_data(budget_description, budget_amount, budget_request_data) do
    if budget_request_data.is_budget_request_on do
      [
        format_budget_request(budget_amount, budget_request_data.budget_currency_code),
        budget_description
      ]
    else
      []
    end
  end

  defp prepare_org_data(data) do
    org_data = %{
      org_uuid: data.org_uuid,
      org_name: data.org_name
    }

    if(data.outcome_type == "learning") do
      Map.put(org_data, :learning_outcomes, prepare_outcome_data(data))
    else
      Map.put(org_data, :success_outcomes, prepare_outcome_data(data))
    end
  end

  defp prepare_outcome_data(data) do
    [
      %{
        uuid: data.outcome_uuid,
        outcome_name: data.outcome_title,
        outcome_set_name: data.outcome_set_name,
        description: data.description,
        status: decode_outcome_status(data, data.measures, data.actions),
        conclusion: data.outcome_analysis,
        measures: data.measures,
        outcome_actions: data.actions
      }
    ]
  end

  defp decode_action_status(nil, _), do: ""
  defp decode_action_status(_, "maintainassessmentstrategy"), do: gettext("Not Applicable")
  defp decode_action_status(action_status_id, _), do: format_action_status(action_status_id)

  defp format_action_status(0), do: gettext("Not Started")
  defp format_action_status(1), do: gettext("In Progress")
  defp format_action_status(2), do: gettext("Complete")

  defp format_budget_request(nil, _currency_code), do: ""

  defp format_budget_request(amount, currency_code) do
    if amount == 0 do
      ""
    else
      format_currency_symbol(currency_code) <>
        format_budget_amount(amount) <> " " <> currency_code
    end
  end

  defp format_currency_symbol(currency_code) do
    case currency_code do
      "GBP" ->
        "£"

      "PKR" ->
        "Rs"

      _ ->
        "$"
    end
  end

  defp format_budget_amount(amount) do
    amount
    |> Integer.to_charlist()
    |> Enum.reverse()
    |> Enum.chunk_every(3, 3, [])
    |> Enum.join(",")
    |> String.reverse()
  end

  defp get_report_headers_for_budget_request(is_budget_request_on) do
    if is_budget_request_on do
      [gettext("Budget Request"), gettext("Budget Description")]
    else
      []
    end
  end

  defp get_outcome_archived_details(true), do: gettext("Yes")
  defp get_outcome_archived_details(false), do: gettext("No")
  defp get_outcome_archived_details(_), do: ""

  defp format_action_due_date(date) when is_nil(date), do: ""

  defp format_action_due_date(date) do
    {:ok, date} = Timex.parse(Date.to_string(date), "{YYYY}-{0M}-{0D}")
    {:ok, formated_date} = Timex.format(date, "{0M}/{0D}/{YYYY}")
    formated_date
  end

  defp get_current_date() do
    Timex.format!(Date.utc_today(), "{0M}{0D}{YYYY}")
  end

  defp decode_action_category("other", other_category),
    do: gettext("Other") <> " - [" <> other_category <> "]"

  defp decode_action_category("maintainassessmentstrategy", _),
    do: gettext("Maintain Assessment Strategy")

  defp decode_action_category("revisecurriculum", _), do: gettext("Revise Curriculum")

  defp decode_action_category("restructureoutcomestatement", _),
    do: gettext("Restructure Outcome Statement")

  defp decode_action_category("revisemeasurementassessment", _),
    do: gettext("Revise Measurement / Assessment")

  defp decode_action_category("gatheradditionaldata", _),
    do: gettext("Gather Additional Data")

  defp decode_action_category("revisebenchmarktarget", _),
    do: gettext("Revise Benchmark / Target")

  defp decode_action_category("implementnewprogramorservices", _),
    do: gettext("Implement New Program or Services")

  defp decode_action_category("communitypartnership", _),
    do: gettext("Community Partnership")

  defp decode_action_category("modifypositionpersonnel", _),
    do: gettext("Modify Position / Personnel")

  defp decode_action_category("modifypoliciesprocedures", _),
    do: gettext("Modify Policies / Procedures")

  defp decode_action_category("additionaltraining", _),
    do: gettext("Additional Training")

  defp decode_action_category("adoptorexpandtechnologies", _),
    do: gettext("Adopt or Expand Technologies")

  defp decode_action_category("collaboratewithanotherdepartmentunitprogram", _),
    do: gettext("Collaborate with another department / unit / program")

  defp decode_action_category("modifyphysicalenvironment", _),
    do: gettext("Modify Physical Environment")

  defp decode_action_category(_, _), do: ""
end
