from typing import Any
from typing import cast
from typing import Iterable
from typing import Mapping
from typing import Sequence

import semgrep.formatter.base as base
import semgrep.semgrep_interfaces.semgrep_output_v1 as out
from semgrep.error import SemgrepError
from semgrep.external.junit_xml import TestCase  # type: ignore[attr-defined]
from semgrep.external.junit_xml import TestSuite  # type: ignore[attr-defined]
from semgrep.external.junit_xml import to_xml_report_string  # type: ignore[attr-defined]
from semgrep.rule import Rule
from semgrep.rule_match import RuleMatch


class JunitXmlFormatter(base.BaseFormatter):
    @staticmethod
    def _rule_match_to_test_case(rule_match: RuleMatch) -> TestCase:  # type: ignore
        test_case = TestCase(
            rule_match.rule_id,
            file=str(rule_match.path),
            line=rule_match.start.line,
            classname=str(rule_match.path),
        )
        test_case.add_failure_info(
            message=rule_match.message,
            output="".join(rule_match.lines),
            failure_type=rule_match.severity.to_json(),
        )
        return test_case

    def format(
        self,
        rules: Iterable[Rule],
        rule_matches: Iterable[RuleMatch],
        semgrep_structured_errors: Sequence[SemgrepError],
        cli_output_extra: out.CliOutputExtra,
        extra: Mapping[str, Any],
        ctx: base.FormatContext,
    ) -> str:
        # Sort according to RuleMatch.get_ordering_key
        sorted_findings = sorted(rule_matches)
        test_cases = [
            self._rule_match_to_test_case(rule_match) for rule_match in sorted_findings
        ]
        ts = TestSuite("semgrep results", test_cases)
        return cast(str, to_xml_report_string([ts]))
