# Generated by Django 3.2.7 on 2022-09-07 19:31

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("data_refinery_common", "0070_auto_20211208_2118"),
    ]

    operations = [
        migrations.CreateModel(
            name="AccessionBacklogEntry",
            fields=[
                (
                    "id",
                    models.AutoField(
                        auto_created=True,
                        primary_key=True,
                        serialize=False,
                        verbose_name="ID",
                    ),
                ),
                ("code", models.TextField(unique=True)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("last_modified_at", models.DateTimeField(auto_now=True)),
                ("organism", models.TextField()),
                ("published_date", models.DateTimeField()),
                ("sample_count", models.PositiveIntegerField(default=0)),
                ("source", models.TextField()),
                ("technology", models.TextField()),
            ],
            options={
                "db_table": "accession_backlog",
            },
        ),
    ]
