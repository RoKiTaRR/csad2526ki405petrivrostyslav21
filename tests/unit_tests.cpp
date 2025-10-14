#include <gtest/gtest.h>
#include "../math_operations.h"

TEST(AddFunctionTest, PositiveNumbers) {
    EXPECT_EQ(add(2, 3), 5);
}

TEST(AddFunctionTest, PositiveAndNegative) {
    EXPECT_EQ(add(5, -3), 2);
}

TEST(AddFunctionTest, NegativeNumbers) {
    EXPECT_EQ(add(-4, -6), -10);
}

TEST(AddFunctionTest, AddWithZero) {
    EXPECT_EQ(add(0, 7), 7);
    EXPECT_EQ(add(7, 0), 7);
    EXPECT_EQ(add(0, 0), 0);
}

// main for Google Test
int main(int argc, char **argv) {
    ::testing::InitGoogleTest(&argc, argv);
    return RUN_ALL_TESTS();
}