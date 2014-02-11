class ReportMailer < ActionMailer::Base
  default from: 'Innovation Blog Stats <noreply@cphepdev.com>'
  
  def csv(report)
    attachments[report.file_name] = File.read(report)
    mail(to: report.email, subject: report.subject, body: "The report is attached.")
  end
  
end
