import unittest

from rspec_prediction import predict


class PredictionTest(unittest.TestCase):
    def test_cold_start_runs_everything(self):
        specs = ["spec/lib/slug_spec.rb", "spec/lib/url_helper_spec.rb"]
        self.assertEqual(predict(specs=specs, changed=["lib/url_helper.rb"], history=[])["specs"], specs)

    def test_configuration_requires_full_selection(self):
        plan = predict(specs=["spec/lib/slug_spec.rb"], changed=["config/routes.rb"], history=[])
        self.assertEqual(plan["mode"], "full")
        self.assertEqual(plan["reason"], "Shared or untraceable input changed")

    def test_model_learns_failure_history_and_keeps_new_tests(self):
        history = [
            {"created_at": f"{index:04}", "changed_files": ["lib/shared.rb"], "specs": {
                "spec/models/consumer_spec.rb": {"failed": True},
                "spec/models/unrelated_spec.rb": {"failed": False},
            }} for index in range(100)
        ]
        plan = predict(specs=["spec/models/consumer_spec.rb", "spec/models/unrelated_spec.rb", "spec/models/new_spec.rb"], changed=["lib/shared.rb"], history=history)
        self.assertEqual(plan["mode"], "subset")
        self.assertEqual(plan["specs"], ["spec/models/consumer_spec.rb", "spec/models/new_spec.rb"])
        self.assertEqual(plan["evaluation"]["missed_failures"], 0)
        self.assertEqual(plan["evaluation"]["failing_changes"], 20)

    def test_history_without_regressions_is_insufficient(self):
        history = [{"created_at": str(index), "changed_files": ["lib/shared.rb"], "specs": {"spec/models/consumer_spec.rb": {"failed": False}}} for index in range(20)]
        self.assertEqual(predict(specs=["spec/models/consumer_spec.rb"], changed=["lib/shared.rb"], history=history)["mode"], "full")


if __name__ == "__main__":
    unittest.main()
