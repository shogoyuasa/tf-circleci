provider "aws" {
    region     = "ap-northeast-1"
}

resource "aws_instance" "sample-ec2" {
    ami           = "ami-0c3fd0f5d33134a76"
    instance_type = "t2.micro"
    monitoring    = false
}
