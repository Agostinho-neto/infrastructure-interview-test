const baseUrl = process.env.BASE_URL || "http://localhost:8080";

function assert(condition, message) {
    if (!condition) {
        throw new Error(message);
    }
}

async function run() {
    console.log(`Testing ${baseUrl}/posts`);

    const response = await fetch(`${baseUrl}/posts`);

    assert(response.status === 200, `Expected status 200, received ${response.status}`);

    const posts = await response.json();

    assert(Array.isArray(posts), "Expected the response to be an array");

    console.log("PASS: GET /posts returned a list");

    const newPost = {
        title: `smoke-test-${Date.now()}`,
        text: "Created by automated smoke test"
    };

    const createResponse = await fetch(`${baseUrl}/posts`, {
        method: "POST",
        headers: {
            "Content-Type": "application/json"
        },
        body: JSON.stringify(newPost)
    });

    assert(
        createResponse.status === 200,
        `Expected status 200 when creating a post, received ${createResponse.status}`
    );

    const createdPost = await createResponse.json();

    assert(createdPost.id, "Expected the created post to contain an id");
    assert(createdPost.title === newPost.title, "Created post returned an unexpected title");
    assert(createdPost.text === newPost.text, "Created post returned unexpected text");

    console.log(`PASS: POST /posts created post ${createdPost.id}`);

    const getByIdResponse = await fetch(`${baseUrl}/posts/${createdPost.id}`);

    assert(
        getByIdResponse.status === 200,
        `Expected status 200 when reading the post, received ${getByIdResponse.status}`
    );

    const persistedPost = await getByIdResponse.json();

    assert(persistedPost.id === createdPost.id, "Returned an unexpected post id");
    assert(persistedPost.title === newPost.title, "Persisted post has an unexpected title");
    assert(persistedPost.text === newPost.text, "Persisted post has unexpected text");

    console.log(`PASS: GET /posts/${createdPost.id} returned the created post`);

    const missingPostId = createdPost.id + 1000000;
    const missingPostResponse = await fetch(`${baseUrl}/posts/${missingPostId}`);

    assert(
        missingPostResponse.status === 404,
        `Expected status 404 for a missing post, received ${missingPostResponse.status}`
    );

    console.log(`PASS: GET /posts/${missingPostId} returned 404`);
}

run().catch(error => {
    console.error(`FAIL: ${error.message}`);
    process.exitCode = 1;
});