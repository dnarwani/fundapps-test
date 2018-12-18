resource "aws_iam_instance_profile" "iam_profile" {
  name = "${var.name}-app-test"
  role = "${aws_iam_role.role.name}"
}

resource "aws_iam_role" "role" {
  name = "${var.name}-role"
  path = "/"

  assume_role_policy = <<EOF
{
    "Version": "2008-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {"AWS": "*"},
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}

resource "aws_iam_role_policy" "allow_s3_access" {
  name = "${var.name}-allow_s3_access"
  role = "${aws_iam_role.role.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
        {
            "Action": [
                "s3:Get*",
                "s3:List*",
                "s3:Put*"
            ],
            "Effect": "Allow",
            "Resource": "*"
        }
    ]
}
EOF
}