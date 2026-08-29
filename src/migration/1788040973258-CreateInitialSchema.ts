import {MigrationInterface, QueryRunner} from "typeorm";

export class CreateInitialSchema1788040973258 implements MigrationInterface {

    public async up(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`
            CREATE TABLE category (
                id INT NOT NULL AUTO_INCREMENT,
                name VARCHAR(255) NOT NULL,
                PRIMARY KEY (id)
            ) ENGINE=InnoDB
        `);

        await queryRunner.query(`
            CREATE TABLE post (
                id INT NOT NULL AUTO_INCREMENT,
                title VARCHAR(255) NOT NULL,
                text TEXT NOT NULL,
                PRIMARY KEY (id)
            ) ENGINE=InnoDB
        `);

        await queryRunner.query(`
            CREATE TABLE post_categories_category (
                postId INT NOT NULL,
                categoryId INT NOT NULL,
                PRIMARY KEY (postId, categoryId),
                CONSTRAINT FK_post_categories_post
                    FOREIGN KEY (postId) REFERENCES post(id)
                    ON DELETE CASCADE,
                CONSTRAINT FK_post_categories_category
                    FOREIGN KEY (categoryId) REFERENCES category(id)
                    ON DELETE CASCADE
            ) ENGINE=InnoDB
        `);
    }

    public async down(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query("DROP TABLE post_categories_category");
        await queryRunner.query("DROP TABLE post");
        await queryRunner.query("DROP TABLE category");
    }

}
